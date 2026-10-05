import Foundation

@main
struct PowerSnapshotChecks {
    static func main() throws {
        let normal = """
        Battery Power:
         hibernatemode        3
         sleep                1
        AC Power:
         hibernatemode        3
         sleep                1
        """

        let sleep = try PowerSnapshot.parse(
            live: "Currently in use:\n sleep 1\n hibernatemode 3\n",
            custom: normal,
            source: "Now drawing from 'AC Power'"
        )
        precondition(sleep.lidMode == .sleep)
        precondition(sleep.powerSource == "接电源")

        let hibernateCustom = normal.replacingOccurrences(
            of: "hibernatemode        3", with: "hibernatemode        25"
        )
        let hibernate = try PowerSnapshot.parse(
            live: "Currently in use:\n SleepDisabled 0\n hibernatemode 25\n",
            custom: hibernateCustom,
            source: "Now drawing from 'Battery Power'"
        )
        precondition(hibernate.lidMode == .hibernate)

        let keepRunning = try PowerSnapshot.parse(
            live: "Currently in use:\n SleepDisabled 1\n hibernatemode 25\n",
            custom: hibernateCustom,
            source: "Now drawing from 'Battery Power'"
        )
        precondition(keepRunning.lidMode == .keepRunning)

        let mixed = normal.replacingOccurrences(
            of: "AC Power:\n hibernatemode        3",
            with: "AC Power:\n hibernatemode        25"
        )
        let custom = try PowerSnapshot.parse(
            live: "Currently in use:\n SleepDisabled 0\n hibernatemode 3\n",
            custom: mixed,
            source: ""
        )
        precondition(custom.lidMode == nil)

        let withUPS = hibernateCustom.replacingOccurrences(
            of: "AC Power:\n hibernatemode        25", with: "AC Power:\n hibernatemode        3"
        ) + "\nUPS Power:\n hibernatemode 25\n"
        let extraProfile = try PowerSnapshot.parse(
            live: "Currently in use:\n SleepDisabled 0\n hibernatemode 3\n",
            custom: withUPS, source: "Now drawing from 'AC Power'"
        )
        precondition(extraProfile.acHibernateMode == 3,
                     "An extra power profile must not overwrite AC settings")
        precondition(!extraProfile.matchesTarget(.hibernate))

        for malformedCustom in [
            normal.replacingOccurrences(of: "sleep                1", with: "hibernatemode garbage"),
            normal.replacingOccurrences(of: "sleep                1", with: "hibernatemode 25")
        ] {
            do {
                _ = try PowerSnapshot.parse(
                    live: "Currently in use:\n hibernatemode 3\n",
                    custom: malformedCustom, source: ""
                )
                preconditionFailure("Ambiguous or malformed custom settings were accepted")
            } catch PowerError.unreadableSettings {}
        }

        for malformedLive in [
            "",
            "garbage",
            "Currently in use:\n SleepDisabled garbage\n hibernatemode 3\n",
            "Currently in use:\n SleepDisabled 0\n SleepDisabled 1\n hibernatemode 3\n"
        ] {
            do {
                _ = try PowerSnapshot.parse(live: malformedLive, custom: normal, source: "")
                preconditionFailure("Malformed live settings were accepted")
            } catch PowerError.unreadableSettings {
                // Invalid live settings must not be presented as ordinary sleep.
            }
        }

        precondition(LidMode.hibernate.pmsetArguments == ["-a", "hibernatemode", "25", "disablesleep", "0"])
        precondition(LidMode.sleep.pmsetArguments == ["-a", "hibernatemode", "3", "disablesleep", "0"])
        precondition(LidMode.keepRunning.pmsetArguments == ["-a", "hibernatemode", "3", "disablesleep", "1"])

        print("power logic checks passed")
    }
}
