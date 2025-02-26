// musical-constraints.scd
// Module for handling scales, modes, and tension/resolution

(
// Scale definitions (MIDI note offsets from root)
~scales = (
    minorPent: [0, 3, 5, 7, 10],
    naturalMinor: [0, 2, 3, 5, 7, 8, 10],
    dorian: [0, 2, 3, 5, 7, 9, 10]
);

// default musical state
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

// Reverb settings for different instruments
~reverbSettings = (
    // Per-instrument reverb amounts (0.0 - 1.0)
    amounts: (
        Piano: 0.3,      // Medium reverb
        Marimba: 0.15,   // Less reverb for clarity
        Flute: 0.4       // More reverb for air
    ),

    // Global reverb parameters
    roomSize: 0.6,
    dampening: 0.5,
    mix: 0.45
);

// Pattern relationship definitions
~patternRelationships = (
    // Relationship settings
    // Controls how strongly patterns influence each other
    influenceStrength: 0.3,  // Global influence probability (0.0-1.0)
    globalPhaseShift: 1/8,   // Default phase shift fraction

    // Specific instrument relationships
    relationships: (
        // Piano influences marimba rhythms
        piano_marimba: (
            source: \Piano,
            target: \Marimba,
            property: \rhythm,      // Affects rhythm
            strength: 0.4,          // Probability of influence
            mode: \adopt,           // How influence works (adopt, reflect, counter)
            active: true            // Can be toggled on/off
        ),

        // Marimba influences flute pitch
        marimba_flute: (
            source: \Marimba,
            target: \Flute,
            property: \pitch,
            strength: 0.35,
            intervals: [3, 4, 7],   // Preferred intervals for pitch relationships
            mode: \follow,
            active: true
        ),

        // Flute influence on piano dynamics
        flute_piano: (
            source: \Flute,
            target: \Piano,
            property: \velocity,
            strength: 0.25,
            mode: \contrast,        // Create contrast rather than similarity
            variance: 0.2,          // How much variance in the influence
            active: true
        )
    ),

    // Phase relationships
    phasing: (
    // Basic phase relationship
    primary: (
        instruments: [\Piano, \Marimba, \Flute],
        phaseShift: 1/8,       // Amount to shift each pattern
        shiftEvery: 32,        // Apply shifts every 32 beats
        staggered: true,       // Apply shifts in staggered manner
        active: true           // Enable this relationship
    ),

    // Counter-phase relationship (opposite direction)
    counter: (
        instruments: [\Marimba, \Flute],
        phaseShift: -1/12,     // Negative for counter-phasing
        shiftEvery: 48,
        staggered: false,
        active: false          // Inactive by default
    )
),

    // Functions to apply the relationships
    // These will be defined in main.scd
    applyInfluence: nil,          // Will be function reference
    applyPhasing: nil             // Will be function reference
);

// Musical Transformation Controls
// These control pattern interactions based on musical state
~transformControls = (
    // Activating relationships based on tension
    tensionActivation: (
        low: 25,      // Below this, minimal interaction
        medium: 50,   // Medium interactions
        high: 75      // Maximum interactions
    ),

    // Phase behavior controls
    phaseControl: (
        minBeats: 16,    // Minimum beats between phase changes
        maxBeats: 64,    // Maximum beats between phase changes
        tensionFactor: 0.5  // How much tension affects phase timing (0-1)
    ),

    // Relationship strength based on harmonic state
    harmonyInfluence: (
        // Influence strength multipliers for different scale types
        minorPent: 1.0,      // Reference value
        naturalMinor: 1.2,   // Increased influence
        dorian: 0.8          // Decreased influence
    )
);
);