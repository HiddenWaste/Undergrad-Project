Server.killAll;
Server.freeAll;

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

    // Instrument-specific pattern constraints
    ~instrumentConstraints = (
        // Pattern length limits per instrument
        patternLimits: (
            Piano: (min: 1, max: 8),     // Piano can have 1-8 notes in pattern
            Marimba: (min: 2, max: 10),  // Marimba can have 2-10 notes
            Flute: (min: 1, max: 3)      // Flute stays minimal with 1-3 notes
        ),

        // Pitch ranges per instrument
        pitchRanges: (
            Piano: (low: 48, high: 84),   // C3 to C6
            Marimba: (low: 60, high: 96), // C4 to C7
            Flute: (low: 72, high: 96)    // C5 to C7
        )
    );

    // Create global reverb bus and synth
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
        ~musicalState.root = 64;  // Middle C
        ~musicalState.scale = \naturalMinor;

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

        // Safely get instrument constraints with fallbacks
        var instrumentKey = instrument.asSymbol;  // Ensure it's a symbol
        var constraints = ~instrumentConstraints.patternLimits[instrumentKey];

        // Default constraints if none defined for this instrument
        var minLength = if(constraints.notNil && constraints[\min].notNil) {
            constraints[\min]
        } {
            ~controlVars.minPatternLength
        };

        var maxLength = if(constraints.notNil && constraints[\max].notNil) {
            constraints[\max]
        } {
            ~controlVars.maxPatternLength
        };

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
            if(currentPattern.size < maxLength, {
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
            if(currentPattern.size > minLength, {
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

    // Apply influences between patterns based on relationships
    ~applyPatternInfluence = { |sourceInstr, targetInstr, relationship|
        var sourcePattern, targetPattern, property, strength, result;
        var modified = false;

        // Check if both patterns exist
        sourcePattern = ~activePatternData[sourceInstr.asString];
        targetPattern = ~activePatternData[targetInstr.asString];

        if(sourcePattern.isNil || targetPattern.isNil) {
            // Can't apply influence if either pattern is missing
            ^[targetPattern, false, "No change - missing pattern"];
        };

        // Calculate effective strength based on musical state
        property = relationship.property;
        strength = relationship.strength * ~patternRelationships.influenceStrength;

        // Adjust strength based on current scale
        if(~transformControls.harmonyInfluence[~musicalState.scale].notNil) {
            strength = strength * ~transformControls.harmonyInfluence[~musicalState.scale];
        };

        // Apply influence based on property and mode
        result = switch(property,
            \rhythm, {
                // Rhythm influence
                var newPattern = targetPattern.copy;
                var operation = "No change";

                if(strength.coin, {
                    switch(relationship.mode,
                        \adopt, {
                            // Adopt rhythm from source occasionally
                            newPattern = newPattern.collect({ |event, i|
                                var sourceIndex = i % sourcePattern.size;
                                event.copy.put(\dur, sourcePattern[sourceIndex].dur);
                            });
                            operation = "Adopted rhythm from %".format(sourceInstr);
                            modified = true;
                        },
                        \contrast, {
                            // Create contrasting rhythm
                            newPattern = newPattern.collect({ |event, i|
                                var sourceIndex = i % sourcePattern.size;
                                var sourceDur = sourcePattern[sourceIndex].dur;
                                var newDur = [0.25, 0.5, 0.125].choose;

                                // Avoid same duration as source
                                while { newDur == sourceDur } {
                                    newDur = [0.25, 0.5, 0.125].choose;
                                };

                                event.copy.put(\dur, newDur);
                            });
                            operation = "Created rhythmic contrast to %".format(sourceInstr);
                            modified = true;
                        }
                    );
                });

                [newPattern, modified, operation];
            },

            \pitch, {
                // Pitch influence
                var newPattern = targetPattern.copy;
                var operation = "No change";
                var intervals = relationship.intervals ? [3, 4, 7];

                if(strength.coin, {
                    switch(relationship.mode,
                        \follow, {
                            // Follow pitches with intervals
                            newPattern = newPattern.collect({ |event, i|
                                var sourceIndex = i % sourcePattern.size;
                                var sourceNote = sourcePattern[sourceIndex].note;
                                var interval = intervals.choose;
                                var newNote = sourceNote + interval;

                                // Keep in valid range
                                newNote = newNote.clip(~controlVars.minPitch, ~controlVars.maxPitch);

                                // Adjust to valid scale degree if needed
                                if(~isValidNote.(newNote).not) {
                                    newNote = ~getNextNotes.(1)[0];
                                };

                                event.copy.put(\note, newNote);
                            });
                            operation = "Followed pitch contour of %".format(sourceInstr);
                            modified = true;
                        }
                    );
                });

                [newPattern, modified, operation];
            },

            \velocity, {
                // Velocity/dynamics influence
                var newPattern = targetPattern.copy;
                var operation = "No change";
                var variance = relationship.variance ? 0.2;

                if(strength.coin, {
                    switch(relationship.mode,
                        \contrast, {
                            // Create contrasting dynamics
                            newPattern = newPattern.collect({ |event, i|
                                var sourceIndex = i % sourcePattern.size;
                                var sourceVel = sourcePattern[sourceIndex].vel;
                                var newVel;

                                // Invert the dynamic relationship
                                newVel = ~controlVars.velocityMax - sourceVel + ~controlVars.velocityMin;

                                // Add some variance
                                newVel = newVel * rrand(1.0 - variance, 1.0 + variance);
                                newVel = newVel.clip(~controlVars.velocityMin, ~controlVars.velocityMax);

                                event.copy.put(\vel, newVel);
                            });
                            operation = "Created dynamic contrast to %".format(sourceInstr);
                            modified = true;
                        },

                        \follow, {
                            // Follow dynamic profile
                            newPattern = newPattern.collect({ |event, i|
                                var sourceIndex = i % sourcePattern.size;
                                var sourceVel = sourcePattern[sourceIndex].vel;
                                var newVel;

                                // Follow with variance
                                newVel = sourceVel * rrand(1.0 - variance, 1.0 + variance);
                                newVel = newVel.clip(~controlVars.velocityMin, ~controlVars.velocityMax);

                                event.copy.put(\vel, newVel);
                            });
                            operation = "Followed dynamics of %".format(sourceInstr);
                            modified = true;
                        }
                    );
                });

                [newPattern, modified, operation];
            },

            // Default if property not recognized
            {
                [targetPattern, false, "No change - unknown property"];
            }
        );

        result;
    };

    // Apply phasing to patterns based on phase relationships
    ~applyPatternPhasing = { |phaseRelationship|
    var instruments = phaseRelationship[\instruments];
    var operations = [];
    var results = [];
    var modified = false;

    // Safety check - if no instruments specified, use defaults
    if(instruments.isNil) {
        instruments = [\Piano, \Marimba, \Flute];
    };

    // Skip first instrument as reference
    for(1, instruments.size-1, { |i|
        var instr = instruments[i];
        var patternKey = instr.asString;
        var pattern = ~activePatternData[patternKey];

        if(pattern.notNil) {
            var phaseShift = phaseRelationship[\phaseShift];
            var rotateAmount;

            // Default phase shift if not specified
            if(phaseShift.isNil) { phaseShift = 1/8 };

            // Calculate rotation amount
            rotateAmount = (pattern.size * phaseShift).asInteger;

            // Apply staggered shifts if enabled
            if(phaseRelationship[\staggered] == true) {
                rotateAmount = rotateAmount * i;
            };

            // Only rotate if we have a valid amount
            if(rotateAmount != 0) {
                // Apply the phase shift
                var newPattern = pattern.rotate(rotateAmount);

                // Store the result
                ~activePatternData[patternKey] = newPattern;

                operations = operations.add(
                    "Phase shift applied to % (shift: % steps)".format(instr, rotateAmount)
                );

                results = results.add([newPattern, instr]);
                modified = true;
            };
        };
    });

    [results, modified, operations];
};

    // Enhanced pattern evolution that includes relationship interactions
    ~enhancedEvolvePattern = { |currentPattern, instrument|
        var result = ~evolvePattern.(currentPattern, instrument);
        var newPattern = result[0];
        var operation = result[1];
        var influenceApplied = false;

        // Evolve first using normal rules
        // Then check for influences from other patterns

        // Only apply influences if tension is above threshold
        if(~musicalState.tension >= ~transformControls.tensionActivation.low) {
            ~patternRelationships.relationships.keysValuesDo({ |key, rel|
                // Check each relationship to see if it applies to this instrument
                if(rel.active && rel.target == instrument) {
                    var influenceResult = ~applyPatternInfluence.(rel.source, rel.target, rel);

                    // If influence caused a change, update pattern and operation
                    if(influenceResult[1]) {  // If modified flag is true
                        newPattern = influenceResult[0];
                        operation = operation ++ " + " ++ influenceResult[2];
                        influenceApplied = true;
                    };
                };
            });
        };

        [newPattern, operation, influenceApplied];
    };

    // Setup routine for periodic phase shifts
    ~setupPhasePatterns = {
    var phaseRoutine;

    "Setting up phase relationships".postln;

    phaseRoutine = Routine({
        inf.do({ |i|
            // Only check phase relationships every beat
            ~patternRelationships.phasing.keysValuesDo({ |key, rel|
                // Only process active relationships
                if(rel[\active] == true) {
                    var shiftEvery = rel[\shiftEvery];

                    // Default value
                    if(shiftEvery.isNil) { shiftEvery = 32 };

                    // Check if it's time for a phase shift
                    if((~globalBeat.asInteger % shiftEvery.asInteger) == 0 && (~globalBeat.asInteger > 0)) {
                        var result = ~applyPatternPhasing.(rel);

                        // Only process if something changed
                        if(result[1] == true) {
                            // Post the changes
                            if(result[2].size > 0) {
                                result[2].do({ |op| op.postln; });
                            };

                            // Also post updated patterns
                            if(result[0].size > 0) {
                                result[0].do({ |patternInfo|
                                    ~postPattern.(
                                        patternInfo[1],  // instrument
                                        patternInfo[0],  // pattern
                                        "Phase shift applied",
                                        ~globalBeat
                                    );
                                });
                            };

                            "=== Phase shift applied at beat % ===".format(~globalBeat).postln;
                        };
                    };
                };
            });

            1.wait;  // Check every beat
        });
    });

    phaseRoutine.play(~mainClock);
    ~activePatterns.add(phaseRoutine);
};

    // Connect the relationships to the implementation functions
    ~patternRelationships.applyInfluence = ~applyPatternInfluence;
    ~patternRelationships.applyPhasing = ~applyPatternPhasing;

    // Create evolving pattern
    // Create evolving pattern - updated version with debug info
~createEvolvingPattern = { |instrument, basePattern, amp=0.2|
    var patternKey = instrument.asString;
    var player;

    // Debug logging
    "Creating evolving pattern for %".format(instrument).postln;

    // Store initial pattern data
    ~activePatternData[patternKey] = basePattern.copy;

    // Initial output includes beat position 0
    ~postPattern.(instrument, basePattern, "Initial pattern", ~globalBeat);

    player = Routine({
        var counter = 0;
        var evolutionCounter = 0;

        inf.do({ |i|
            var currentPattern = ~activePatternData[patternKey];
            var index = counter % currentPattern.size;
            var noteEvent = currentPattern[index];

            // Debug logging - uncomment if needed
            // if(i % 16 == 0) {
            //    "% playing note % of % at beat %".format(
            //        instrument, index, currentPattern.size, ~globalBeat).postln;
            // };

            // Play the current note using reverb
            ~playWithReverb.((
                instrument: instrument,
                midinote: noteEvent.note,
                amp: noteEvent.vel * amp
            ));

            // Check if it's time to evolve the pattern
            if(evolutionCounter >= ~controlVars.additionRate, {
                var oldPattern = currentPattern.copy;

                // Make sure we're using the correct function
                var result = ~evolvePattern.(currentPattern, instrument);
                ~activePatternData[patternKey] = result[0];  // Store updated pattern

                if(oldPattern != result[0], {
                    // Use global beat tracker here
                    ~postPattern.(instrument, result[0], result[1], ~globalBeat);
                });

                evolutionCounter = 0;
            });

            // Update counters
            counter = counter + 1;
            evolutionCounter = evolutionCounter + noteEvent.dur;

            // Wait for the duration of this note before playing the next
            noteEvent.dur.wait;
        });
    });

    // Start the pattern playing on the main clock
    player.play(~mainClock);
    ~activePatterns.add(player);

    // Return the player for potential manual control
    player;
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

        // Initialize phase relationships
        ~setupPhasePatterns.value();

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
        ~postPattern.value(\Piano, pianoBase);
        ~createEvolvingPattern.value(
            \Piano,
            pianoBase,
            0.2
        );

        // Add marimba after 32 beats
        ~mainClock.sched(32, {
            ~postPattern.value(\Marimba, marimbaBase);
            ~createEvolvingPattern.value(
                \Marimba,
                marimbaBase,
                0.15
            );
        });

        // Add flute after 64 beats
        ~mainClock.sched(64, {
            ~postPattern.value(\Flute, fluteBase);
            ~createEvolvingPattern.value(
                \Flute,
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

s.reboot;
s.meter;
s.plotTree;
~startDemo.value;
~cleanup.value;