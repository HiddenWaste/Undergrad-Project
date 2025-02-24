(
// First load the SynthDefs and musical constraints
(thisProcess.nowExecutingPath.dirname +/+ "glass-synthdefs.scd").load;
(thisProcess.nowExecutingPath.dirname +/+ "musical-constraints.scd").load;

// Wrap everything in waitForBoot
Server.default.waitForBoot({
    // SECTION 1: GLOBAL VARIABLES AND SETTINGS
    var tempo = 120;
    var clockDiv = 4;

    // Initialize storage for active elements
    ~activePatterns = List.new;
    ~activePatternData = Dictionary.new;  // New: Store pattern data separately

    ~activeSynths = List.new;

    // Pattern bank generator function with musical constraints
    ~generatePatternBanks = {
        var banks = ();
        var styles = ['basic', 'melodic', 'minimal'];
        var instruments = ['piano', 'marimba', 'flute'];

        // Base notes for each instrument (now using scale-aware system)
        var baseNotes = (
            piano: ~musicalState.root,    // Root note
            marimba: ~musicalState.root,  // Root note
            flute: ~musicalState.root + 12 // Root note + octave
        );

        // Generate banks for each style
        styles.do({ |style|
            banks[style.asSymbol] = ();

            // Generate patterns for each instrument
            instruments.do({ |instr|
                var baseNote = baseNotes[instr.asSymbol];
                var patterns = [];
                var currentPattern;

                // Generate patterns of increasing length using scale-aware note selection
                (2..4).do({ |length|
                    currentPattern = length.collect({ |i|
                        var noteChoices = ~getNextNotes.(1);
                        var note = noteChoices[0];

                        (
                            note: note,
                            vel: rrand(0.15, 0.25),
                            dur: case
                                { style == 'minimal' } { 0.25 }
                                { style == 'melodic' } { 0.5 }
                                { 0.25 }
                        )
                    });

                    patterns = patterns.add(currentPattern);
                });

                banks[style.asSymbol][instr.asSymbol] = patterns;
            });
        });

        banks
    };

    // Initialize control vars with generated banks and musical state
    ~initializeControlVars = {
        // Initialize musical state first
        ~musicalState.root = 60;  // Middle C
        ~musicalState.scale = \minorPent;

        ~controlVars = (
            // Pattern Evolution Controls
            additionRate: 16,
            subtractionRate: 24,
            maxPatternLength: 8,
            minPatternLength: 2,

            // Musical Controls (new)
            tensionThreshold: 75,  // Point at which we might trigger changes
            modeChangeThreshold: 85,  // Point at which we might change modes

            // Transformation Controls
            transformChance: 0.15,
            stepSize: 1,
            directionChangeChance: 0.1,

            velocityMin: 0.1,
            velocityMax: 0.7,
            velocityStepSize: 0.08,
            velocityChangeChance: 0.2,

            rhythmChangeChance: 0.1,
            rhythmStepSizes: [0.125, 0.25, 0.5, 1.0],
            rhythmMin: 0.125,
            rhythmMax: 1.0,

            systemTransformChance: 0.01,
            maxPitch: 87,
            minPitch: 48,
            resetThreshold: 83,

            bankChangeChance: 0.05,
            currentBank: 'basic',

            isAdditive: true,
            transformationCounter: 0
        );

        ~controlVars.patternBanks = ~generatePatternBanks.value();
    };

    // Call initialize
    ~initializeControlVars.value();

    // SECTION 2: PATTERN EVOLUTION AND UTILITIES

    // Modified pattern evolution function with musical constraints
    // Modified pattern evolution function
~evolvePattern = { |currentPattern, instrument|
    var newPattern = currentPattern.copy;
    var operation = "No change";
    var direction = 1;

    // Update musical state based on all current patterns
    ~updateMusicalState.(~activePatternData.values.asArray);

    // Handle tension-based transformations
    if(~musicalState.tension > ~controlVars.tensionThreshold, {
        // Increase chance of transformation
        ~controlVars.transformChance = 0.25;

        // Consider mode change if tension is very high
        if(~musicalState.tension > ~controlVars.modeChangeThreshold, {
            var modes = ~scales.keys.asArray;
            ~musicalState.scale = modes.choose;
            operation = "Mode changed to %".format(~musicalState.scale);
        });
    }, {
        ~controlVars.transformChance = 0.15;
    });

    // Handle additive/subtractive processes with scale awareness
    if(~controlVars.isAdditive, {
        if(currentPattern.size < ~controlVars.maxPatternLength, {
            var nextNotes = ~getNextNotes.(1);
            var nextNote = (
                note: nextNotes[0],
                vel: currentPattern.last.vel,
                dur: currentPattern.last.dur
            );
            newPattern = newPattern.add(nextNote);
            operation = "Note added (scale-aware)";
        });
    }, {
        if(currentPattern.size > ~controlVars.minPatternLength, {
            newPattern = newPattern.drop(-1);
            operation = "Note removed";
        });
    });

    // Previous evolution logic for velocity
    if(~controlVars.velocityChangeChance.coin, {
        newPattern = newPattern.collect({ |noteEvent|
            var newVel = noteEvent.vel;
            var velDirection = [-1, 1].choose;
            newVel = newVel + (~controlVars.velocityStepSize * velDirection);
            newVel = newVel.clip(~controlVars.velocityMin, ~controlVars.velocityMax);
            noteEvent.putAll((vel: newVel));
            noteEvent;
        });
        operation = operation ++ " + Velocity changed";
    });

    [newPattern, operation];
};

    // Utility functions
    ~noteToName = { |note|
        var names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
        var octave = (note / 12).floor - 1;
        var noteName = names[note % 12];
        noteName ++ octave
    };

    ~postPattern = { |instrument, notes, operation="No change"|
        var noteInfo = notes.collect({ |n|
            "% (vel: %, dur: %)".format(
                ~noteToName.(n.note),
                n.vel.round(0.01),
                n.dur
            )
        });
        "=== Pattern Change ===".postln;
        ("Instrument: " ++ instrument).postln;
        ("Operation: " ++ operation).postln;
        ("Notes: " ++ noteInfo.join(", ")).postln;
        "".postln;
    };

    // Create evolving pattern
    ~createEvolvingPattern = { |instrument, basePattern, amp=0.2|
        var patternKey = instrument.asString;
        var player;

        // Store initial pattern data
        ~activePatternData[patternKey] = basePattern.copy;

        player = Routine({
            var counter = 0;
            var evolutionCounter = 0;

            inf.do({ |i|
                var currentPattern = ~activePatternData[patternKey];
                var index = counter % currentPattern.size;
                var noteEvent = currentPattern[index];

                (
                    instrument: instrument,
                    midinote: noteEvent.note,
                    amp: noteEvent.vel * amp
                ).play;

                if(evolutionCounter >= ~controlVars.additionRate, {
                    var oldPattern = currentPattern.copy;
                    var result = ~evolvePattern.(currentPattern, instrument);
                    ~activePatternData[patternKey] = result[0];  // Store updated pattern

                    if(oldPattern != result[0], {
                        ~postPattern.(instrument, result[0], result[1]);
                    });

                    evolutionCounter = 0;
                });

                counter = counter + 1;
                evolutionCounter = evolutionCounter + noteEvent.dur;

                noteEvent.dur.wait;
            });
        });

        player.play(~mainClock);
        ~activePatterns.add(player);
    };

    // SECTION 3: TIMING AND CONTROL
    ~mainClock = TempoClock.new(tempo/60);

    // Cleanup function
    ~cleanup = {
        ~activePatterns.do(_.stop);
        ~activeSynths.do(_.free);
        ~mainClock.stop;
    };

    // SECTION 4: DEMO ROUTINE
    ~startDemo = {
        var pianoBase = ~getNextNotes.(2).collect({ |note|
            (note: note, vel: 0.2, dur: 0.25)
        });

        var marimbaBase = ~getNextNotes.(2).collect({ |note|
            (note: note, vel: 0.2, dur: [0.5, 0.25].choose)
        });

        var fluteBase = ~getNextNotes.(2).collect({ |note|
            (note: note, vel: 0.2, dur: [1.0, 0.5].choose)
        });

        "=== Starting Glass-inspired Demo with Evolution ===".postln;
        "Initial patterns will evolve every % beats".format(~controlVars.additionRate).postln;
        "".postln;

        // Start piano
        ~postPattern.value(\glassPiano, pianoBase);
        ~createEvolvingPattern.value(
            \glassPiano,
            pianoBase,
            0.2
        );

        // Add marimba after 32 beats
        ~mainClock.sched(32, {
            ~postPattern.value(\glassMarimba, marimbaBase);
            ~createEvolvingPattern.value(
                \glassMarimba,
                marimbaBase,
                0.15
            );
        });

        // Add flute after 64 beats
        ~mainClock.sched(64, {
            ~postPattern.value(\glassFlute, fluteBase);
            ~createEvolvingPattern.value(
                \glassFlute,
                fluteBase,
                0.1
            );

            // Switch to subtractive after 96 more beats
            ~mainClock.sched(96, {
                "=== Switching to Subtractive Process ===".postln;
                ~controlVars.isAdditive = false;
            });
        });
    };

    // Print setup confirmation
    "Glass-inspired system foundation loaded successfully.".postln;
    "Use ~startDemo.value to begin the evolving patterns".postln;
    "Use ~cleanup.value when finished.".postln;
});
);

~startDemo.value;