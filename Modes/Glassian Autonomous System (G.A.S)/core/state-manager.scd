// state-manager.scd
// Central system state and parameter management for the Glass-inspired system
// Handles system parameters, musical state, and runtime operations

/*
  Usage:
  1. Initialize using ~stateManager.init()
  2. Load a preset using ~stateManager.loadPreset(presetName)
  3. Start/stop the system using ~stateManager.start() and ~stateManager.stop()
  4. Update parameters using ~stateManager.updateParam(path, value)
*/

(
// Create namespace for the state manager
~stateManager = ();

// Initialize the state manager
~stateManager.init = { |clockTempo=120|
  var initialState;
  
  // Initialize system clock
  ~stateManager.clock = TempoClock.new(clockTempo/60);
  
  // Initialize global message function
  ~stateManager.log = { |message, type=\info|
    var timestamp = Date.getDate.format("%H:%M:%S");
    var formattedMessage = "[%] [%] %".format(timestamp, type, message);
    
    formattedMessage.postln;
    
    // Store the message in the runtime log
    if(~stateManager.state.notNil) {
      if(~stateManager.state.runtime.notNil && ~stateManager.state.runtime.messages.notNil) {
        ~stateManager.state.runtime.messages.add((
          time: timestamp,
          type: type,
          message: message
        ));
        
        // Keep only the last 100 messages
        if(~stateManager.state.runtime.messages.size > 100) {
          ~stateManager.state.runtime.messages.removeAt(0);
        };
      };
    };
    
    // Return the formatted message
    formattedMessage;
  };
  
  // Initialize system state
  initialState = (
    // Global timing and clock settings
    timing: (
      tempo: clockTempo,        // BPM
      clockDiv: 4,              // Clock division
      swingAmount: 0,           // 0-1 range for swing
      globalReset: 512          // Number of beats before considering a global reset
    ),

    // Process settings
    process: (
      // Current process state
      currentProcess: \additive,  // Current process type (\additive or \subtractive)
      
      // Additive/Subtractive mode timings
      additiveDuration: 128,     // Duration of additive phase in beats
      subtractiveDuration: 96,   // Duration of subtractive phase in beats

      // Evolution rate controls
      additionRate: 16,          // How often to add elements
      subtractionRate: 24,       // How often to remove elements

      // Basic constraints
      maxPatternLength: 8,
      minPatternLength: 2,

      // Transformation controls
      transformChance: 0.15,      // Base chance for transformations
      systemTransformChance: 0.01
    ),

    // Audio settings
    audio: (
      // Master volume and mix controls
      masterVolume: 0.8,  // 0-1 range

      // Default instrument volumes
      instrumentVolumes: (
        piano: 0.7,
        marimba: 0.8,
        flute: 0.6
      ),
      
      // Default instrument panning
      instrumentPans: (
        piano: 0,
        marimba: 0.3,
        flute: -0.3
      ),
      
      // Reverb settings
      reverb: (
        roomSize: 0.6,
        dampening: 0.5,
        mix: 0.45,
        
        // Per-instrument reverb amounts (0.0 - 1.0)
        amounts: (
          piano: 0.3,      // Medium reverb
          marimba: 0.2,    // Less reverb for clarity
          flute: 0.4       // More reverb for air
        )
      )
    ),
    
    // Timeline for the system
    timeline: (),
    
    // Runtime state
    runtime: (
      isPlaying: false,         // Whether the system is currently playing
      currentBeat: 0,           // Current beat position
      currentSection: nil,      // Current section name
      activePatterns: (),       // Currently active patterns
      activeRoutines: List.new, // Active routines for cleanup
      activeSynths: List.new,   // Active synths for cleanup
      messages: List.new        // System messages for logging
    ),

    // Musical controls
    musical: (
      root: 60,                 // Starting root note (Middle C)
      scale: \major,            // Starting scale
      tension: 0,               // Current tension level (0-100)
      harmonicDensity: 0,       // Current harmonic density (0-100)
      rhythmicDensity: 0,       // Current rhythmic density (0-100)
      verticalSpread: 0,        // Current vertical spread (0-100)

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
      instruments: ['piano', 'marimba', 'flute'],
      
      instrumentEnabled: ( // Keeps track of which instruments are currently enabled
        piano: false,      // Start inactive, enabled via timeline events
        marimba: false,
        flute: false
      ),

      // Default starting patterns for instruments
      initialPatterns: (
        piano: [
          (note: 60, vel: 0.2, dur: 0.25),
          (note: 62, vel: 0.2, dur: 0.25)
        ],
        marimba: [
          (note: 60, vel: 0.2, dur: 0.5),
          (note: 64, vel: 0.2, dur: 0.25)
        ],
        flute: [
          (note: 72, vel: 0.2, dur: 1.0),
          (note: 67, vel: 0.2, dur: 0.5)
        ]
      ),

      // Pattern relationships - how instruments influence each other
      relationships: (
        // Piano influences marimba rhythms
        piano_marimba: (
          source: \piano,
          target: \marimba,
          property: \rhythm,      // Affects rhythm
          strength: 0.4,          // Probability of influence
          mode: \adopt,           // How influence works (adopt, reflect, counter)
          active: true            // Can be toggled on/off
        ),

        // Marimba influences flute pitch
        marimba_flute: (
          source: \marimba,
          target: \flute,
          property: \pitch,
          strength: 0.35,
          intervals: [3, 4, 7],   // Preferred intervals for pitch relationships
          mode: \follow,
          active: true
        ),

        // Flute influence on piano dynamics
        flute_piano: (
          source: \flute,
          target: \piano,
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
          instruments: [\piano, \marimba, \flute],
          phaseShift: 1/8,       // Amount to shift each pattern
          shiftEvery: 32,        // Apply shifts every 32 beats
          staggered: true,       // Apply shifts in staggered manner
          active: true           // Enable this relationship
        )
      ),
      
      // Global influence settings
      influenceStrength: 0.3     // Global scaling for pattern influences
    ),
    
    // Instrument specific constraints
    instrumentConstraints: (
      // Pattern length limits for each instrument
      patternLimits: (
        piano: (min: 2, max: 8),    // Piano can have longer patterns
        marimba: (min: 2, max: 6),  // Medium length for marimba
        flute: (min: 1, max: 4)     // Shorter patterns for flute
      ),
      
      // When instruments enter in the sequence (in beats)
      entryTimes: (
        piano: 0,      // Start immediately
        marimba: 32,   // Enter after 32 beats
        flute: 64      // Enter after 64 beats
      )
    ),
    
    // Set up musical scales
    scales: (
      major: [0, 2, 4, 5, 7, 9, 11],
      naturalMinor: [0, 2, 3, 5, 7, 8, 10],
      harmonicMinor: [0, 2, 3, 5, 7, 8, 11],
      melodicMinor: [0, 2, 3, 5, 7, 9, 11],
      dorian: [0, 2, 3, 5, 7, 9, 10],
      phrygian: [0, 1, 3, 5, 7, 8, 10],
      lydian: [0, 2, 4, 6, 7, 9, 11],
      mixolydian: [0, 2, 4, 5, 7, 9, 10],
      locrian: [0, 1, 3, 5, 6, 8, 10],
      minorPent: [0, 3, 5, 7, 10],
      majorPent: [0, 2, 4, 7, 9]
    )
  );
  
  // Assign the initial state
  ~stateManager.state = initialState;
  
  ~stateManager.log.("State Manager initialized with tempo: %".format(clockTempo));
  
  // Return for chaining
  ~stateManager;
};

// Update a parameter in the state
~stateManager.updateParam = { |path, value|
  var parts = path.split($.);
  var current = ~stateManager.state;
  
  // Navigate to the correct nested object
  if(parts.size > 1) {
    parts[0..(parts.size-2)].do { |part|
      var partSym = part.asSymbol;
      if(current[partSym].isNil) {
        current[partSym] = ();
      };
      current = current[partSym];
    };
    
    // Set the value
    current[parts.last.asSymbol] = value;
  } {
    // Set directly on state
    ~stateManager.state[path.asSymbol] = value;
  };
  
  value;
};

// Get a parameter from the state
~stateManager.getParam = { |path|
  var parts = path.split($.);
  var current = ~stateManager.state;
  
  // Navigate to the correct nested object
  parts.do { |part|
    var partSym = part.asSymbol;
    if(current.isNil) { ^nil };
    current = current[partSym];
  };
  
  current;
};

// Load a preset into the state
~stateManager.loadPreset = { |preset|
  if(preset.isNil) {
    ~stateManager.log.("Cannot load nil preset", \error);
    ^false;
  };
  
  // Update the state with the preset values
  preset.keysValuesDo { |key, value|
    if(key != \name && key != \description && key != \author && key != \created) {
      ~stateManager.updateParam.(key, value);
    };
  };
  
  ~stateManager.log.("Loaded preset: %".format(preset[\name] ? "Unnamed"));
  
  true;
};

// Start the beat counter with instrument entries
~stateManager.startBeatCounter = {
  var beatCounter = Routine({
    inf.do {
      var beat = ~stateManager.state.runtime.currentBeat;
      var entryTimes = ~stateManager.state.instrumentConstraints.entryTimes;
      
      // Check if we need to start any instruments at this beat
      if(entryTimes.notNil) {
        if(beat == entryTimes.piano && ~stateManager.getParam.("patterns.instrumentEnabled.piano").not) {
          ~stateManager.log.("Starting piano at beat %".format(beat));
          
          // Create a timeline event for starting piano
          ~timelineInterpreter.executeEvent.((
            beat: beat,
            type: \instrumentStart,
            instrument: \piano
          ));
        };
        
        if(beat == entryTimes.marimba && ~stateManager.getParam.("patterns.instrumentEnabled.marimba").not) {
          ~stateManager.log.("Starting marimba at beat %".format(beat));
          
          // Create a timeline event for starting marimba
          ~timelineInterpreter.executeEvent.((
            beat: beat,
            type: \instrumentStart,
            instrument: \marimba
          ));
        };
        
        if(beat == entryTimes.flute && ~stateManager.getParam.("patterns.instrumentEnabled.flute").not) {
          ~stateManager.log.("Starting flute at beat %".format(beat));
          
          // Create a timeline event for starting flute
          ~timelineInterpreter.executeEvent.((
            beat: beat,
            type: \instrumentStart,
            instrument: \flute
          ));
        };
      };
      
      // Occasionally log the current beat
      if(beat % 32 == 0) {
        ~stateManager.log.("Beat: %".format(beat));
      };
      
      // Increment beat counter
      ~stateManager.state.runtime.currentBeat = beat + 1;
      
      1.wait;  // Wait one beat
    };
  });
  
  beatCounter.play(~stateManager.clock);
  ~stateManager.state.runtime.activeRoutines.add(beatCounter);
  ~stateManager.log.("Beat counter started");
  
  beatCounter;
};

// Convert MIDI note to note name
~stateManager.noteToName = { |note|
  var names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
  var octave = (note / 12).floor - 1;
  var noteName = names[note % 12];
  noteName ++ octave.asString;
};

// Print current state
~stateManager.printState = {
  ~stateManager.log.("=== System State ===");
  ~stateManager.log.("Status: %".format(
    if(~stateManager.state.runtime.isPlaying) { "Running" } { "Stopped" }
  ));
  ~stateManager.log.("Current Beat: %".format(~stateManager.state.runtime.currentBeat));
  ~stateManager.log.("Tempo: % BPM".format(~stateManager.state.timing.tempo));
  ~stateManager.log.("Process: %".format(~stateManager.state.process.currentProcess));
  ~stateManager.log.("Musical Root: % (%)"
    .format(~stateManager.state.musical.root, ~stateManager.noteToName.(~stateManager.state.musical.root)));
  ~stateManager.log.("====================");
};

"State Manager module loaded successfully.".postln;
~stateManager;
)

