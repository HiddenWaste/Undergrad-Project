// default.scd
// Default preset for the Glass-inspired generative system

(
// Basic system information
name: "Default Glass System",
description: "Default preset with balanced parameters for a Glass-like sound",
author: "System",
created: Date.getDate.format("%Y-%m-%d"),

// Global timing settings
timing: (
  tempo: 110,        // BPM
  clockDiv: 4,       // Clock division
  swingAmount: 0,    // 0-1 range for swing
  globalReset: 512   // Number of beats before considering a global reset
),

// Process settings
process: (
  // Current process state
  currentProcess: \additive,  // Initial process type (\additive or \subtractive)

  // Additive/Subtractive mode timings
  additiveDuration: 128,     // Duration of additive phase in beats
  subtractiveDuration: 96,   // Duration of subtractive phase in beats

  // Evolution rate controls
  additionRate: 16,          // How often to add elements (in beats)
  subtractionRate: 24,       // How often to remove elements (in beats)

  // Basic constraints
  maxPatternLength: 8,       // Maximum pattern length
  minPatternLength: 2,       // Minimum pattern length

  // Transformation controls
  transformChance: 0.15,     // Base chance for transformations
  systemTransformChance: 0.01 // Chance for system-wide transformations
),

// Audio settings
audio: (
  // Master volume and mix controls
  masterVolume: 0.8,  // 0-1 range

  // Default instrument volumes
  instrumentVolumes: (
    Piano: 0.2,
    Marimba: 0.15,
    Flute: 0.1
  ),

  // Default instrument panning
  instrumentPans: (
    Piano: 0,
    Marimba: 0.3333,
    Flute: -0.3333
  ),

  // Reverb settings
  reverb: (
    roomSize: 0.4,
    dampening: 0.5,
    mix: 0.45,

    // Per-instrument reverb amounts (0.0 - 1.0)
    amounts: (
      Piano: 0.3,      // Medium reverb
      Marimba: 0.15,   // Less reverb for clarity
      Flute: 0.4       // More reverb for air
    )
  )
),

// Musical controls
musical: (
  root: 64,                 // Starting root note (E)
  scale: \naturalMinor,     // Starting scale

  tensionThreshold: 75,     // Point at which we might trigger changes
  modeChangeThreshold: 85,  // Point at which we might change modes

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

// Pattern settings
patterns: (
  bankChangeChance: 0.05,
  initialBank: 'basic',
  styles: ['basic', 'melodic', 'minimal'],
  instruments: ['Piano', 'Marimba', 'Flute'],

  instrumentEnabled: ( // Keeps track of which instruments are currently enabled
    Piano: true,
    Marimba: true,
    Flute: true
  ),

  // Default starting patterns for instruments
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
    ]
  ),

  // Timing for when instruments enter in the sequence
  instrumentEntryTimes: (
    Piano: 0,     // Start immediately
    Marimba: 32,  // Enter after 32 beats
    Flute: 64     // Enter after 64 beats
  ),

  // Pattern relationships - how instruments influence each other
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
    )
  ),

  // Global influence settings
  influenceStrength: 0.3     // Global scaling for pattern influences
),

// Timeline events for the preset
timeline: [
  // Section marker for intro
  (
    beat: 0,
    type: \sectionMarker,
    name: "intro"
  ),

  // Start Piano immediately
  (
    beat: 0,
    type: \instrumentStart,
    instrument: \Piano
  ),

  // Set initial process
  (
    beat: 0,
    type: \processChange,
    process: \additive
  ),

  // Bring in Marimba after 32 beats
  (
    beat: 32,
    type: \instrumentStart,
    instrument: \Marimba
  ),

  // Section marker for development
  (
    beat: 64,
    type: \sectionMarker,
    name: "development"
  ),

  // Start Flute at development
  (
    beat: 64,
    type: \instrumentStart,
    instrument: \Flute
  ),

  // Change process to subtractive
  (
    beat: 128,
    type: \processChange,
    process: \subtractive
  ),

  // Change scale
  (
    beat: 192,
    type: \scaleChange,
    scale: \dorian
  ),

  // Section marker for conclusion
  (
    beat: 256,
    type: \sectionMarker,
    name: "conclusion"
  ),

  // Return to additive
  (
    beat: 256,
    type: \processChange,
    process: \additive
  ),

  // Loop back to the beginning
  (
    beat: 384,
    type: \sectionJump,
    section: "intro"
  )
]
)