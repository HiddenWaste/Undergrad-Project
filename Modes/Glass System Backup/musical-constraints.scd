// musical-constraints.scd
// Module for handling scales, modes, and tension/resolution

(
// Scale definitions (MIDI note offsets from root)
~scales = (
    minorPent: [0, 3, 5, 7, 10],
    naturalMinor: [0, 2, 3, 5, 7, 8, 10],
    dorian: [0, 2, 3, 5, 7, 9, 10]
);

// Current musical state
~musicalState = (
    root: 64,  // E for tonic note
    scale: \dorian,
    tension: 0,  // 0-100
    harmonicDensity: 0,  // 0-100
    rhythmicDensity: 0,  // 0-100
    verticalSpread: 0    // 0-100
);

// Generate notes in current scale
~getScaleNotes = { |root, numOctaves = 2|
    var scale = ~scales[~musicalState.scale];
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
    var scale = ~scales[~musicalState.scale];
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

// Modified: Update tension based on current pattern data
~updateTension = {
    var newTension;

    newTension = (
        (~musicalState.harmonicDensity * 0.4) +
        (~musicalState.rhythmicDensity * 0.3) +
        (~musicalState.verticalSpread * 0.3)
    ).clip(0, 100);

    ~musicalState.tension = newTension;
};

// Modified: Update musical state based on current patterns
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

~reverbSettings = (
    // Per-instrument reverb amounts (0.0 - 1.0)
    amounts: (
        glassPiano: 0.25,    // Medium reverb
        glassMarimba: 0.15,  // Less reverb for clarity
        glassFlute: 0.35     // More reverb for air
    ),

    // Global reverb parameters
    roomSize: 0.6,
    dampening: 0.5,
    mix: 0.3
);
);