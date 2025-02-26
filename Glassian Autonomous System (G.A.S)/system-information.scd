// system-information.scd
// Central parameter storage for the Glass-inspired generative system

(
// CORE SYSTEM PARAMETERS
~systemParams = (
    // Global timing and clock settings
    timing: (
        tempo: 120,        // BPM
        clockDiv: 4,       // Clock division
        swingAmount: 0,    // 0-1 range for swing
        globalReset: 512   // Number of beats before considering a global reset
    ),

    // Process settings
    process: (
        // Additive/Subtractive mode timings
        additiveDuration: 128,    // Duration of additive phase in beats
        subtractiveDuration: 96,  // Duration of subtractive phase in beats

        // Evolution rate controls
        additionRate: 16,         // How often to add elements
        subtractionRate: 24,      // How often to remove elements

        // Basic constraints
        maxPatternLength: 8,
        minPatternLength: 2,

        // Transformation controls
        transformChance: 0.15,     // Base chance for transformations
        systemTransformChance: 0.01
    ),

    // Audio settings
    audio: (
        // Master volume and mix controls
        masterVolume: 0.8,  // 0-1 range

        // Default instrument volumes
        instrumentVolumes: (
            Piano: 0.2,
            Marimba: 0.15,
            Flute: 0.1,
            Harp: 0.12,
            Organ: 0.1,
            Celesta: 0.14
        )
    ),

    // Reverb settings
    reverb: (
        // Global reverb parameters
        roomSize: 0.6,
        dampening: 0.5,
        mix: 0.45,

        // Per-instrument reverb amounts (0.0 - 1.0)
        amounts: (
            Piano: 0.3,      // Medium reverb
            Marimba: 0.15,   // Less reverb for clarity
            Flute: 0.4,      // More reverb for air
            Harp: 0.35,      // Medium-high reverb
            Organ: 0.25,     // Medium reverb
            Celesta: 0.2     // Lighter reverb
        )
    ),

    // Musical controls
    musical: (
        initialRoot: 64,           // Starting root note (E)
        initialScale: \naturalMinor,// Starting scale

        tensionThreshold: 75,      // Point at which we might trigger changes
        modeChangeThreshold: 85,   // Point at which we might change modes

        // Velocity controls
        velocityMin: 0.1,
        velocityMax: 0.7,
        velocityStepSize: 0.08,
        velocityChangeChance: 0.2,

        // Rhythm controls
        rhythmChangeChance: 0.1,
        rhythmStepSizes: [0.125, 0.25, 0.5, 1.0],
        rhythmMin: 0.125,
        rhythmMax: 1.0,

        // Pitch boundaries
        maxPitch: 87,
        minPitch: 48,
        resetThreshold: 83
    ),

    // Pattern generation controls
    patterns: (
        bankChangeChance: 0.05,
        initialBank: 'basic',
        styles: ['basic', 'melodic', 'minimal'],
        instruments: ['Piano', 'Marimba', 'Flute', 'Harp', 'Celesta', 'Organ'],

        // Default starting patterns for demo
        initialPatterns: (
            Piano: [
                (note: 60, vel: 0.2, dur: 0.25),
                (note: 62, vel: 0.2, dur: 0.25)
            ],
            Marimba: [
                (note: 60, vel: 0.2, dur: 0.5),
                (note: 64, vel: 0.2, dur: 0.25)
            ],
            Flute: [
                (note: 72, vel: 0.2, dur: 1.0),
                (note: 67, vel: 0.2, dur: 0.5)
            ],
            Harp: [
                (note: 64, vel: 0.25, dur: 0.5),
                (note: 67, vel: 0.2, dur: 0.5),
                (note: 71, vel: 0.18, dur: 0.5)
            ],
            Organ: [
                (note: 48, vel: 0.15, dur: 1.0),
                (note: 55, vel: 0.15, dur: 1.0)
            ],
            Celesta: [
                (note: 72, vel: 0.18, dur: 0.25),
                (note: 76, vel: 0.15, dur: 0.25),
                (note: 79, vel: 0.12, dur: 0.25)
            ]
        ),

        // Timing for when instruments enter in the demo sequence
        instrumentEntryTimes: (
            Piano: 0,     // Start immediately
            Marimba: 32,  // Enter after 32 beats
            Flute: 64,    // Enter after 64 beats
            Harp: 96,     // Enter after 96 beats
            Organ: 128,   // Enter after 128 beats
            Celesta: 160  // Enter after 160 beats
        )
    )
);

// Scales from the musical-constraints file
~systemParams.scales = (
    minorPent: [0, 3, 5, 7, 10],
    naturalMinor: [0, 2, 3, 5, 7, 8, 10],
    dorian: [0, 2, 3, 5, 7, 9, 10]
);

// Instrument constraints from the main file
~systemParams.instrumentConstraints = (
    // Pattern length limits per instrument
    patternLimits: (
        Piano: (min: 1, max: 8),     // Piano can have 1-8 notes in pattern
        Marimba: (min: 2, max: 10),  // Marimba can have 2-10 notes
        Flute: (min: 1, max: 3),     // Flute stays minimal with 1-3 notes
        Harp: (min: 2, max: 6),      // Harp has medium patterns
        Organ: (min: 1, max: 4),     // Organ has shorter patterns
        Celesta: (min: 2, max: 8)    // Celesta has medium patterns
    ),

    // Pitch ranges per instrument
    pitchRanges: (
        Piano: (low: 48, high: 84),   // C3 to C6
        Marimba: (low: 60, high: 96), // C4 to C7
        Flute: (low: 72, high: 96),   // C5 to C7
        Harp: (low: 48, high: 88),    // C3 to E6
        Organ: (low: 36, high: 72),   // C2 to C5
        Celesta: (low: 60, high: 96)  // C4 to C7
    )
);

// Pattern relationships from the paste-2 file
~systemParams.patternRelationships = (
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
    )
);

// Presets for different musical styles
~systemParams.presets = (
    // Minimal Glass-like preset
    minimal: (
        tempo: 130,
        process: (
            additiveDuration: 96,
            subtractiveDuration: 64,
        ),
        musical: (
            initialRoot: 60,              // C
            initialScale: \minorPent,     // Pentatonic scale
            tensionThreshold: 70,         // Lower tension threshold
        ),
        reverb: (
            roomSize: 0.5,
            dampening: 0.4,
            mix: 0.4
        ),
        patternRelationships: (
            influenceStrength: 0.2        // Less pattern influence
        )
    ),

    // More complex/intricate preset
    complex: (
        tempo: 110,
        process: (
            additiveDuration: 144,
            subtractiveDuration: 112,
        ),
        musical: (
            initialRoot: 64,              // E
            initialScale: \dorian,        // Dorian mode
            tensionThreshold: 80,         // Higher tension threshold
        ),
        reverb: (
            roomSize: 0.7,                // More reverb
            dampening: 0.3,
            mix: 0.5
        ),
        patternRelationships: (
            influenceStrength: 0.4        // More pattern influence
        )
    )
);

// Function to load a preset
~loadPreset = { |presetName|
    var preset = ~systemParams.presets[presetName.asSymbol];

    if(preset.notNil, {
        // Update tempo if specified
        if(preset[\tempo].notNil, {
            ~systemParams.timing.tempo = preset[\tempo];
            if(~mainClock.notNil, {
                ~mainClock.tempo = preset[\tempo] / 60;
            });
        });

        // Process parameters
        if(preset[\process].notNil, {
            preset[\process].keysValuesDo({ |k, v|
                ~systemParams.process[k] = v;
            });
        });

        // Musical parameters
        if(preset[\musical].notNil, {
            preset[\musical].keysValuesDo({ |k, v|
                ~systemParams.musical[k] = v;
            });

            // Update musical state if it exists
            if(~musicalState.notNil, {
                if(preset[\musical][\initialRoot].notNil, {
                    ~musicalState.root = preset[\musical][\initialRoot];
                });
                if(preset[\musical][\initialScale].notNil, {
                    ~musicalState.scale = preset[\musical][\initialScale];
                });
            });
        });

        // Reverb parameters
        if(preset[\reverb].notNil && ~reverbSynth.notNil, {
            preset[\reverb].keysValuesDo({ |k, v|
                ~systemParams.reverb[k] = v;
            });

            // Update reverb synth
            ~reverbSynth.set(
                \room, ~systemParams.reverb.roomSize,
                \damp, ~systemParams.reverb.dampening,
                \mix, ~systemParams.reverb.mix
            );
        });

        // Pattern relationships
        if(preset[\patternRelationships].notNil, {
            preset[\patternRelationships].keysValuesDo({ |k, v|
                ~systemParams.patternRelationships[k] = v;
            });
        });

        "Preset '%' loaded successfully.".format(presetName).postln;
    }, {
        "Preset '%' not found.".format(presetName).error;
    });
};

// Function to save current settings as a new preset
~savePreset = { |presetName|
    var newPreset = (
        tempo: ~systemParams.timing.tempo,
        process: (
            additiveDuration: ~systemParams.process.additiveDuration,
            subtractiveDuration: ~systemParams.process.subtractiveDuration
        ),
        musical: (
            initialRoot: ~musicalState.root,
            initialScale: ~musicalState.scale,
            tensionThreshold: ~systemParams.musical.tensionThreshold
        ),
        reverb: (
            roomSize: ~systemParams.reverb.roomSize,
            dampening: ~systemParams.reverb.dampening,
            mix: ~systemParams.reverb.mix
        ),
        patternRelationships: (
            influenceStrength: ~systemParams.patternRelationships.influenceStrength
        )
    );

    ~systemParams.presets[presetName.asSymbol] = newPreset;
    "Current settings saved as preset '%'.".format(presetName).postln;
};

"System parameters loaded successfully.".postln;
)