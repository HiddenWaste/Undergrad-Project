// main.scd
// Glass-inspired generative music system
// Refactored to use central parameter system

Server.killAll;

(
// First load the system information, SynthDefs, and musical constraints
(thisProcess.nowExecutingPath.dirname +/+ "system-information.scd").load;
(thisProcess.nowExecutingPath.dirname +/+ "glass-synthdefs.scd").load;
(thisProcess.nowExecutingPath.dirname +/+ "musical-constraints.scd").load;

// Wrap everything in waitForBoot
Server.default.waitForBoot({
    // SECTION 1: GLOBAL VARIABLES AND STORAGE INITIALIZATION

    // Initialize global beat counter
    ~globalBeat = 0;

    // Initialize storage for active elements
    ~activePatterns = List.new;
    ~activePatternData = Dictionary.new;
    ~activeSynths = List.new;

    // SECTION 2: AUDIO INFRASTRUCTURE SETUP

    // Create global reverb bus and synth
    ~createGlobalReverb = {
        // Create a stereo bus for the reverb
        ~reverbBus = Bus.audio(Server.default, 2);

        // Create and store the reverb synth instance
        ~reverbSynth = Synth.after(1, \globalReverb, [
            \in, ~reverbBus,
            \out, 0,
            \mix, ~systemParams.reverb.mix,
            \room, ~systemParams.reverb.roomSize,
            \damp, ~systemParams.reverb.dampening
        ]);

        // Add the reverb synth to active synths for cleanup
        ~activeSynths.add(~reverbSynth);

        "Global reverb created and running".postln;
    };

    // Play a note with reverb send
    ~playWithReverb = { |args|
        var instrument = args[\instrument];
        var midinote = args[\midinote];
        var amplitude = args[\amp];
        var reverbAmount = ~systemParams.reverb.amounts[instrument] ? 0.2;

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

    // SECTION 3: PATTERN GENERATION AND EVOLUTION

    // Pattern bank generator function with musical constraints
    ~generatePatternBanks = {
        var banks = ();
        var styles = ~systemParams.patterns.styles;
        var instruments = ~systemParams.patterns.instruments;

        // Base notes for each instrument (using scale-aware system)
        var baseNotes = Dictionary.new;
        instruments.do({ |instr|
            baseNotes[instr.asSymbol] = ~musicalState.root;

            // Add octave for higher instruments
            if(instr == 'Flute' || instr == 'Celesta') {
                baseNotes[instr.asSymbol] = baseNotes[instr.asSymbol] + 12;
            };

            // Add lower octave for organ
            if(instr == 'Organ') {
                baseNotes[instr.asSymbol] = baseNotes[instr.asSymbol] - 12;
            };
        });

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

    // Initialize control variables
    ~initializeControlVars = {
        // Load musical state from system parameters (already done in musical-constraints.scd)

        ~controlVars = (
            // Pattern Evolution Controls
            additionRate: ~systemParams.process.additionRate,
            subtractionRate: ~systemParams.process.subtractionRate,
            maxPatternLength: ~systemParams.process.maxPatternLength,
            minPatternLength: ~systemParams.process.minPatternLength,

            // Musical Controls
            tensionThreshold: ~systemParams.musical.tensionThreshold,
            modeChangeThreshold: ~systemParams.musical.modeChangeThreshold,

            // Transformation Controls
            transformChance: ~systemParams.musical.transformChance,
            stepSize: 1,
            directionChangeChance: 0.1,

            velocityMin: ~systemParams.musical.velocityMin,
            velocityMax: ~systemParams.musical.velocityMax,
            velocityStepSize: ~systemParams.musical.velocityStepSize,
            velocityChangeChance: ~systemParams.musical.velocityChangeChance,

            rhythmChangeChance: ~systemParams.musical.rhythmChangeChance,
            rhythmStepSizes: ~systemParams.musical.rhythmStepSizes,
            rhythmMin: ~systemParams.musical.rhythmMin,
            rhythmMax: ~systemParams.musical.rhythmMax,

            systemTransformChance: ~systemParams.process.systemTransformChance,
            maxPitch: ~systemParams.musical.maxPitch,
            minPitch: ~systemParams.musical.minPitch,
            resetThreshold: ~systemParams.musical.resetThreshold,

            bankChangeChance: ~systemParams.patterns.bankChangeChance,
            currentBank: ~systemParams.patterns.initialBank,

            isAdditive: true,
            transformationCounter: 0
        );

        ~controlVars.patternBanks = ~generatePatternBanks.value();
    };

    // Call initialize
    ~initializeControlVars.value();

    // Pattern evolution function
    ~evolvePattern = { |currentPattern, instrument|
        var newPattern = currentPattern.copy;
        var operation = "No change";
        var direction = 1;

        // Safely get instrument constraints with fallbacks
        var instrumentKey = instrument.asSymbol;  // Ensure it's a symbol
        var constraints = ~systemParams.instrumentConstraints.patternLimits[instrumentKey];

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
                var modes = ~systemParams.scales.keys.asArray;
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

        // Velocity evolution
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

    // SECTION 4: PATTERN RELATIONSHIP AND PHASING FUNCTIONS

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
        strength = relationship.strength * ~systemParams.patternRelationships.influenceStrength;

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

                                // Ensure the note is in the current scale
                                if(~isValidNote.(newNote).not, {
                                    newNote = ~getNextNotes.(1)[0];
                                });

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
            instruments = ~systemParams.patterns.instruments.collect(_.asSymbol);
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
                if(phaseShift.isNil) { phaseShift = ~systemParams.patternRelationships.globalPhaseShift };

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

        // Only apply influences if tension is above threshold
        if(~musicalState.tension >= ~systemParams.transformControls.tensionActivation.low) {
            ~systemParams.patternRelationships.relationships.keysValuesDo({ |key, rel|
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
                ~systemParams.patternRelationships.phasing.keysValuesDo({ |key, rel|
                    // Only process active relationships
                    if(rel[\active] == true) {
                        var shiftEvery = rel[\shiftEvery];

                        // Default value if missing
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

    // SECTION 5: UTILITY FUNCTIONS

    // Convert MIDI note to note name
    ~noteToName = { |note|
        var names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
        var octave = (note / 12).floor - 1;
        var noteName = names[note % 12];
        noteName ++ octave
    };

    // Display pattern information
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

    // Create evolving pattern for an instrument
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

                // Play the current note using reverb
                ~playWithReverb.((
                    instrument: instrument,
                    midinote: noteEvent.note,
                    amp: noteEvent.vel * amp
                ));

                // Check if it's time to evolve the pattern
                if(evolutionCounter >= ~controlVars.additionRate, {
                    var oldPattern = currentPattern.copy;

                    // Use enhanced evolution with relationship interactions
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

    // SECTION 6: TIMING AND CONTROL

    // Create main clock with tempo from system parameters
    ~mainClock = TempoClock.new(~systemParams.timing.tempo/60);

    // Global beat tracker
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

    // Cleanup function to stop all patterns and free synths
    ~cleanup = {
        // First stop all patterns
        ~activePatterns.do({ |pat|
            if(pat.isPlaying) { pat.stop }
        });

        // Free all synths
        ~activeSynths.do({ |syn|
            if(syn.isPlaying) { syn.free }
        });

        // Stop clock last
        if(~mainClock.notNil) {
            if(~mainClock.isPlaying) {
                ~mainClock.stop;
                ~mainClock.clear;
            }
        };

        // Clear collections
        ~activePatterns = List.new;
        ~activePatternData = Dictionary.new;
        ~activeSynths = List.new;

        "System cleaned up".postln;
    };

    // SECTION 7: DEMO ROUTINE

    // Start the generative system with cycling additive/subtractive processes
    ~startDemo = {
        var additiveDuration = ~systemParams.process.additiveDuration;
        var subtractiveDuration = ~systemParams.process.subtractiveDuration;
        var instruments = ~systemParams.patterns.instruments.collect(_.asSymbol);
        var scheduleCycle;

        // Reset and start beat tracker
        ~globalBeat = 0;
        ~startGlobalBeatTracker.value();

        // Initialize phase relationships
        ~setupPhasePatterns.value();

        // Function to schedule cycling between additive and subtractive processes
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

        // Start all instruments at their specified entry times
        instruments.do({ |instr|
            var entryTime = ~systemParams.patterns.instrumentEntryTimes[instr] ? 0;
            var initialPattern = ~systemParams.patterns.initialPatterns[instr];
            var amplitude = ~systemParams.audio.instrumentVolumes[instr] ? 0.2;

            if(initialPattern.notNil) {
                // Schedule the instrument to start at its entry time
                ~mainClock.sched(entryTime, {
                    "Starting % at beat %".format(instr, ~globalBeat).postln;
                    ~postPattern.value(instr, initialPattern);
                    ~createEvolvingPattern.value(
                        instr,
                        initialPattern,
                        amplitude
                    );
                });
            };
        });

        // Start the cycle
        scheduleCycle.value(true);
    };

    // Simplified function to play just one instrument
    ~playInstrument = { |instrument|
        var initialPattern = ~systemParams.patterns.initialPatterns[instrument.asSymbol];
        var amplitude = ~systemParams.audio.instrumentVolumes[instrument.asSymbol] ? 0.2;

        if(initialPattern.notNil) {
            ~postPattern.value(instrument, initialPattern);
            ~createEvolvingPattern.value(
                instrument,
                initialPattern,
                amplitude
            );
            "Started % individually".format(instrument).postln;
        } {
            "No pattern found for %".format(instrument).error;
        };
    };

    // Load a preset and restart if necessary
    ~loadPresetAndRestart = { |presetName|
        var wasRunning = ~activePatterns.size > 0;

        // Stop first if already running
        if(wasRunning) {
            ~cleanup.value();

            // Important: Give the server a moment to clean up
            0.5.wait;
        };

        // Recreate the clock
        ~mainClock = TempoClock.new(~systemParams.timing.tempo/60);

        // Load the preset
        ~loadPreset.value(presetName);

        // Reinitialize control variables
        ~initializeControlVars.value();

        // Create the reverb
        ~createGlobalReverb.value();

        // Reset patterns lists
        ~activePatterns = List.new;
        ~activePatternData = Dictionary.new;

        // Restart if it was running
        if(wasRunning) {
            ~startDemo.value();
        };

        "Preset % loaded with all parameters updated.".format(presetName).postln;
    };

    // IMPORTANT: Create the reverb after all initialization is complete
    // but before starting any patterns
    ~createGlobalReverb.value();

    // Print setup confirmation
    "Glass-inspired system foundation loaded successfully.".postln;
    "Use ~startDemo.value to begin the evolving patterns".postln;
    "Use ~cleanup.value when finished.".postln;
    "Use ~loadPresetAndRestart.('preset_name') to load a preset".postln;
});
)

// Handy execution commands (uncommenting any line will run it)
// s.meter;         // Show audio levels
// s.plotTree;      // Show node tree
~startDemo.value; // Start the full demo
~cleanup.value;   // Stop everything

s.record(duration:40);

// To load presets safely, wrap in a Routine to handle timing:
Routine({
     ~loadPresetAndRestart.('minimal'); // Load minimal preset
 }).play;

// Routine({
//     ~loadPresetAndRestart.('complex'); // Load complex preset
// }).play;

// ~playInstrument.(\Piano);  // Play just the piano pattern

// If you need to reset everything completely:
// {
//     ~cleanup.value;
//     s.freeAll;
//     s.sync;
//     Server.killAll;
//     s.boot;
//     s.sync;
//     "System fully reset and ready to go".postln;
// }.fork;