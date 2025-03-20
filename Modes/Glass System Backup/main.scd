

(
// First load the SynthDefs and musical constraints
(thisProcess.nowExecutingPath.dirname +/+ "glass-synthdefs.scd").load;
(thisProcess.nowExecutingPath.dirname +/+ "musical-constraints.scd").load;

// Wrap everything in waitForBoot
Server.default.waitForBoot({
    // SECTION 1: GLOBAL VARIABLES AND SETTINGS
    var tempo = 120;
    var clockDiv = 4;
	~globalBeat = 0;     // Global beat Tracker

    // Initialize storage for active elements
    ~activePatterns = List.new;
    ~activePatternData = Dictionary.new;  // New: Store pattern data separately
    ~activeSynths = List.new;

    // Create global reverb bus and synth - MOVED after initializing ~reverbSettings
    ~createGlobalReverb = {
        // Create a stereo bus for the reverb
        ~reverbBus = Bus.audio(Server.default, 2);

        // Reverb synth definition
        SynthDef(\globalReverb, {
            arg in=0, out=0, mix=0.3, room=0.6, damp=0.5;
            var dry, wet;

            // Input from the bus
            dry = In.ar(in, 2);

            // Create reverb effect
            wet = FreeVerb2.ar(
                dry[0], dry[1],
                mix: mix,
                room: room,
                damp: damp
            );

            // Output the wet signal to master
            Out.ar(out, wet);
        }).add;

        // Create and store the reverb synth instance
        ~reverbSynth = Synth.after(1, \globalReverb, [
            \in, ~reverbBus,
            \out, 0,
            \mix, ~reverbSettings.mix,
            \room, ~reverbSettings.roomSize,
            \damp, ~reverbSettings.dampening
        ]);

        // Add the reverb synth to active synths for cleanup
        ~activeSynths.add(~reverbSynth);

        "Global reverb created and running".postln;
    };

    ~playWithReverb = { |args|
        var instrument = args[\instrument];
        var midinote = args[\midinote];
        var amplitude = args[\amp];
        var reverbAmount = ~reverbSettings.amounts[instrument] ? 0.2;

        // Direct output (drier signal)
        var dryAmp = amplitude * (1 - reverbAmount);
        var drySynth = (
            instrument: instrument,
            midinote: midinote,
            amp: dryAmp,
            out: 0
        ).play;

        // Reverb send (wet signal)
        var wetAmp = amplitude * reverbAmount;
        var wetSynth = (
            instrument: instrument,
            midinote: midinote,
            amp: wetAmp,
            out: ~reverbBus
        ).play;

        // Return both synths (useful if you need to modify them later)
        [drySynth, wetSynth]
    };

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

    ~postPattern = { |instrument, notes, operation="No change", beatPosition=nil|
        var noteInfo = notes.collect({ |n|
            "    % (vel: %, dur: %)".format(
                ~noteToName.(n.note),
                n.vel.round(0.01),
                n.dur
            )
        });

        // Format beat position if provided
        var beatInfo = if(beatPosition.notNil, {
            " at beat %".format(beatPosition.round(0.1))
        }, {
            ""
        });

        "=== Pattern Change% ===".format(beatInfo).postln;
        ("Instrument: " ++ instrument).postln;
        ("Operation: " ++ operation).postln;
        "Notes:".postln;
        noteInfo.do({ |info| info.postln });
        "".postln;
    };

    // Create evolving pattern
    ~createEvolvingPattern = { |instrument, basePattern, amp=0.2|
    var patternKey = instrument.asString;
    var player;

    // Store initial pattern data
    ~activePatternData[patternKey] = basePattern.copy;

    // Initial output includes beat position 0
    ~postPattern.(instrument, basePattern, "Initial pattern", 0);

    player = Routine({
        var counter = 0;
        var evolutionCounter = 0;
        var beatCounter = 0;  // Track total beats elapsed
        var evolutionInterval = 8;  // Evolve pattern every 8 beats (adjust as needed)

        inf.do({ |i|
            var currentPattern = ~activePatternData[patternKey];
            var index = counter % currentPattern.size;
            var noteEvent = currentPattern[index];

            // Use the playWithReverb function
            ~playWithReverb.((
                instrument: instrument,
                midinote: noteEvent.note,
                amp: noteEvent.vel * amp
            ));

            counter = counter + 1;
            evolutionCounter = evolutionCounter + noteEvent.dur;
            beatCounter = beatCounter + noteEvent.dur;  // Update total beat count

            // Check if it's time to evolve the pattern
            if(evolutionCounter >= evolutionInterval, {
                var result = ~evolvePattern.(currentPattern, instrument);
                var newPattern = result[0];
                var operation = result[1];

                // Update the pattern in the dictionary
                ~activePatternData[patternKey] = newPattern;

                // Post the evolved pattern with current beat position
                ~postPattern.(instrument, newPattern, operation, beatCounter);

                // Reset evolution counter
                evolutionCounter = 0;
            });

            noteEvent.dur.wait;
        });
    });

    player.play(~mainClock);
    ~activePatterns.add(player);
};


    // SECTION 3: TIMING AND CONTROL
    ~mainClock = TempoClock.new(tempo/60);

	~startGlobalBeatTracker = {
    var tracker;
    tracker = Routine({
        inf.do({
            ~globalBeat = ~globalBeat + 1;
            1.wait;  // Wait one beat
        });
    });
    tracker.play(~mainClock);
    ~activePatterns.add(tracker);  // Add to active patterns for cleanup
    "Global beat tracker started".postln;
	};

    // Cleanup function
    ~cleanup = {
        ~activePatterns.do(_.stop);
        ~activeSynths.do(_.free);
        ~mainClock.stop;
    };

    // SECTION 4: DEMO ROUTINE
    // Modified startDemo that cycles between processes
    ~startDemo = {
        var pianoBase = [
            (note: 60, vel: 0.2, dur: 0.25),
            (note: 62, vel: 0.2, dur: 0.25)
        ];
        var marimbaBase = [
            (note: 60, vel: 0.2, dur: 0.5),
            (note: 64, vel: 0.2, dur: 0.25)
        ];
        var fluteBase = [
            (note: 72, vel: 0.2, dur: 1.0),
            (note: 67, vel: 0.2, dur: 0.5)
        ];

        // Define phase durations (in beats)
        var additiveDuration = 128;
        var subtractiveDuration = 96;

        // Create cycler function (schedules the next phase)
        var scheduleCycle;

		~globalBeat = 0;  // Reset global beat counter
~startGlobalBeatTracker.value();


        scheduleCycle = { |isFirstCycle=false|
            if(~controlVars.isAdditive, {
                // Currently additive, schedule switch to subtractive
                ~mainClock.sched(additiveDuration, {
                    "=== Switching to Subtractive Process ===".postln;
                    ~controlVars.isAdditive = false;
                    scheduleCycle.value(false);
                });
            }, {
                // Currently subtractive, schedule switch to additive
                ~mainClock.sched(subtractiveDuration, {
                    "=== Switching to Additive Process ===".postln;
                    ~controlVars.isAdditive = true;
                    scheduleCycle.value(false);
                });
            });
        };

        "=== Starting Glass-inspired Demo with Cycling Processes ===".postln;
        "Will alternate between additive (% beats) and subtractive (% beats) processes.".format(
            additiveDuration, subtractiveDuration
        ).postln;
        "Use ~cleanup.value when finished.".postln;
        "".postln;

        // Initialize to additive mode
        ~controlVars.isAdditive = true;

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
        });

        // Start the cycle
        scheduleCycle.value(true);
    };

    // IMPORTANT: Create the reverb after all initialization is complete
    // but before starting any patterns
    ~createGlobalReverb.value();

    // Print setup confirmation
    "Glass-inspired system foundation loaded successfully.".postln;
    "Use ~startDemo.value to begin the evolving patterns".postln;
    "Use ~cleanup.value when finished.".postln;
});
)

s.plotTree;
~startDemo.value;
~cleanup.value;