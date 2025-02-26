// musical-constraints.scd
// Module for handling scales, modes, and tension/resolution

(
// Load system parameters first if not already loaded
(thisProcess.nowExecutingPath.dirname +/+ "system-information.scd").loadPaths;

// Current musical state
~musicalState = (
    root: ~systemParams.musical.initialRoot,  // Use system parameter
    scale: ~systemParams.musical.initialScale, // Use system parameter
    tension: 0,  // 0-100
    harmonicDensity: 0,  // 0-100
    rhythmicDensity: 0,  // 0-100
    verticalSpread: 0    // 0-100
);

// Generate notes in current scale
~getScaleNotes = { |root, numOctaves = 2|
    var scale = ~systemParams.scales[~musicalState.scale];
    var notes = [];
    numOctaves.do({ |octave|
        scale.do({ |offset|
            notes = notes.add(root + offset + (octave * 12));
        });
    });
    notes;
};

// Check if a note fits current scale
~isValidNote = { |note|
    var scale = ~systemParams.scales[~musicalState.scale];
    var normalizedNote = (note - ~musicalState.root) % 12;
    scale.includes(normalizedNote);
};

// Get weighted note probabilities based on musical state
~getNoteWeights = { |availableNotes|
    var weights = Array.fill(availableNotes.size, 1);
    var tensionPhase = ~musicalState.tension > 50;

    // Adjust weights based on tension
    weights = weights.collect({ |w, i|
        var note = availableNotes[i];
        var weight = w;

        // Favor higher notes in high tension
        if(tensionPhase) {
            weight = weight * (1 + (note - ~musicalState.root)/24);
        };

        // Favor stepwise motion
        if(~lastNote.notNil) {
            var interval = (note - ~lastNote).abs;
            weight = weight * (1 / (1 + (interval/2)));
        };

        weight;
    });

    weights;
};

// Update tension based on current pattern data
~updateTension = {
    var newTension;

    newTension = (
        (~musicalState.harmonicDensity * 0.4) +
        (~musicalState.rhythmicDensity * 0.3) +
        (~musicalState.verticalSpread * 0.3)
    ).clip(0, 100);

    ~musicalState.tension = newTension;
};

// Update musical state based on current patterns
~updateMusicalState = { |patterns|
    var activeNotes, totalNotes = 0, activeDurs = 0;

    // Extract all currently playing notes from patterns
    activeNotes = patterns.collect({ |pat|
        pat.collect({ |event| event.note });
    }).flatten;

    // Update harmonic density
    ~musicalState.harmonicDensity = (activeNotes.size / 12 * 100).clip(0, 100);

    // Update vertical spread
    if(activeNotes.size > 0) {
        var spread = activeNotes.maxItem - activeNotes.minItem;
        ~musicalState.verticalSpread = (spread / 36 * 100).clip(0, 100);
    };

    // Update rhythmic density
    patterns.do({ |pat|
        totalNotes = totalNotes + pat.size;
        activeDurs = activeDurs + pat.sum({ |event| event.dur });
    });

    ~musicalState.rhythmicDensity = (totalNotes / activeDurs * 100).clip(0, 100);

    ~updateTension.value();
};

// Get next suggested notes based on current state
~getNextNotes = { |numNotes = 1|
    var availableNotes = ~getScaleNotes.(~musicalState.root);
    var weights = ~getNoteWeights.(availableNotes);
    var selected = Array.new(numNotes);

    numNotes.do({
        var note = availableNotes.wchoose(weights.normalizeSum);
        selected = selected.add(note);
    });

    selected;
};

// Musical harmony-related functions for transformations
~harmonicTransformations = (
    // Change root note but maintain scale
    changeRoot: { |interval=nil|
        var newRoot;

        // Use provided interval or choose a pleasing interval
        if(interval.isNil, {
            interval = [3, 4, 5, 7, -2, -3].choose;
        });

        newRoot = ~musicalState.root + interval;

        // Keep within reasonable range
        newRoot = newRoot.clip(~systemParams.musical.minPitch,
                               ~systemParams.musical.maxPitch - 12);

        ~musicalState.root = newRoot;
        "Root changed to %".format(~noteToName.(newRoot)).postln;
    },

    // Change scale/mode but maintain root
    changeScale: { |newScale=nil|
        var availableScales = ~systemParams.scales.keys.asArray;
        var currentScale = ~musicalState.scale;

        // Use provided scale or choose one different from current
        if(newScale.isNil, {
            // Remove current scale from choices
            availableScales = availableScales.reject({ |sc| sc == currentScale });
            newScale = availableScales.choose;
        });

        ~musicalState.scale = newScale;
        "Scale changed to %".format(newScale).postln;
    },

    // Invert a pattern (upside down)
    invertPattern: { |pattern|
        var center = ~musicalState.root; // Use root as center
        var result = pattern.collect({ |event|
            var invertedNote = center + (center - event.note);

            // Keep in reasonable range
            invertedNote = invertedNote.clip(~systemParams.musical.minPitch,
                                           ~systemParams.musical.maxPitch);

            // Ensure the note is in the current scale
            if(~isValidNote.(invertedNote).not, {
                invertedNote = ~getNextNotes.(1)[0];
            });

            event.copy.put(\note, invertedNote);
        });

        result;
    },

    // Retrograde a pattern (backwards)
    retrogradePattern: { |pattern|
        pattern.reverse;
    },

    // Transpose a pattern
    transposePattern: { |pattern, interval|
        var result = pattern.collect({ |event|
            var newNote = event.note + interval;

            // Keep in reasonable range
            newNote = newNote.clip(~systemParams.musical.minPitch,
                                 ~systemParams.musical.maxPitch);

            // Ensure the note is in the current scale
            if(~isValidNote.(newNote).not, {
                // Find nearest scale note
                var scale = ~systemParams.scales[~musicalState.scale];
                var normalized = (newNote - ~musicalState.root) % 12;
                var distances = scale.collect({ |sc| (sc - normalized).abs });
                var idx = distances.minIndex;

                newNote = newNote + (scale[idx] - normalized);
            });

            event.copy.put(\note, newNote);
        });

        result;
    }
);

"Musical constraints loaded successfully.".postln;
)