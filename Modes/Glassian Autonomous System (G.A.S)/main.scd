// main.scd
// Main entry point for the Glass-inspired generative music system
// Integrates all modular components with built-in sample functionality

// First, kill any running servers
Server.killAll;

(
// Set up core server options
s.options.numBuffers = 2048;  // Increase buffer count before booting
s.options.memSize = 8192;     // Increase memory for complex processing
s.latency = 0.05;             // Low latency for responsive playback

// Boot the server and initialize the system
s.waitForBoot({
  // ----- CONFIGURATION -----

  // Configure sample paths - modify these to match your sample locations
  ~basePath = "C:/Users/carte/Music/Samples/Iowa Samples/";

  // Folder paths
  ~fluteVibFolder = ~basePath ++ "Flute/Flute.vib.ff.stereo/";
  ~fluteNonvibFolder = ~basePath ++ "Flute/Flute.nonvib.ff.stereo/";
  ~marimbaCordFolder = ~basePath ++ "Marimba/Marimba.cord.ff.stereo/";
  ~marimbaRubberFolder = ~basePath ++ "Marimba/Marimba.rubber.ff.stereo/";
  ~pianoFFFolder = ~basePath ++ "Piano/Piano.ff/";
  ~pianoMFFolder = ~basePath ++ "Piano/Piano.mf/";
  ~pianoPPFolder = ~basePath ++ "Piano/Piano.pp/";

  // System tempo
  ~tempo = 110;

  // Create main system clock
  ~clock = TempoClock.new(~tempo/60);

  "=== Glass-inspired Generative Music System ===".postln;
  "Initializing system with tempo: %".format(~tempo).postln;

  // ----- LOAD MODULES -----

  // Load and initialize the state manager
  "Loading state-manager.scd...".postln;
  (thisProcess.nowExecutingPath.dirname +/+ "core\\state-manager.scd").load;
  ~stateManager.init(~tempo);

  // Load and initialize musical constraints
  "Loading musical-constraints.scd...".postln;
  (thisProcess.nowExecutingPath.dirname +/+ "core\\musical-constraints.scd").load;
  ~musicalConstraints.init();

  // Load and initialize pattern engine
  "Loading pattern-engine.scd...".postln;
  (thisProcess.nowExecutingPath.dirname +/+ "core\\pattern-engine.scd").load;
  ~patternEngine.init();

  // Load and initialize timeline interpreter
  "Loading timeline-interpreter.scd...".postln;
  (thisProcess.nowExecutingPath.dirname +/+ "core\\timeline-interpreter.scd").load;
  ~timelineInterpreter.init();

  // Load and initialize data analyst (optional)
  "Loading data-analyst.scd...".postln;
  (thisProcess.nowExecutingPath.dirname +/+ "core\\data-analyst.scd").load;
  ~dataAnalyst.init();

  // ----- SAMPLE MANAGER (INTEGRATED) -----

  "Initializing integrated sample functionality...".postln;

  // Create namespace for the sample manager
  ~sampleManager = ();

  // Initialize samples and instruments dictionaries
  ~sampleManager.samples = Dictionary.new;
  ~sampleManager.instruments = Dictionary.new;
  ~sampleManager.activeSynths = Dictionary.new;

  // Create instrument dictionaries
  ~sampleManager.samples[\piano] = Dictionary.new;
  ~sampleManager.samples[\piano][\ff] = Dictionary.new;

  ~sampleManager.samples[\marimba] = Dictionary.new;
  ~sampleManager.samples[\marimba][\cord] = Dictionary.new;

  ~sampleManager.samples[\flute] = Dictionary.new;
  ~sampleManager.samples[\flute][\vib] = Dictionary.new;

  // Add basic sample player SynthDef
  SynthDef(\samplePlayer, {
    |buf=0, amp=0.5, pan=0, attack=0.01, release=0.3, out=0, gate=1|
    var sig, env;

    env = EnvGen.kr(Env.asr(attack, 1, release), gate, doneAction: 2);
    sig = PlayBuf.ar(
      numChannels: 2,
      bufnum: buf,
      rate: BufRateScale.kr(buf),
      doneAction: 0  // Let the envelope handle completion
    );
    sig = sig * env * amp;
    sig = Pan2.ar(sig, pan);
    Out.ar(out, sig);
  }).add;

  // Add reverb SynthDef for effects
  SynthDef(\simpleReverb, {
    |in=0, out=0, mix=0.3, room=0.5, damp=0.5|
    var dry, wet;

    dry = In.ar(in, 2);
    wet = FreeVerb.ar(dry, mix, room, damp);
    Out.ar(out, wet);
  }).add;

  // Function to load samples from a folder
  ~loadSampleFolder = { |folderPath, instrument, articulation, notePosition=3|
    var folder = PathName(folderPath);
    var count = 0;

    // Check if folder exists
    if(folder.isFolder.not) {
      "Warning: Folder % does not exist".format(folderPath).warn;
      ^0;
    };

    "Loading % % samples from %".format(instrument, articulation, folderPath).postln;

    folder.files.do { |file|
      if((file.extension == "aif") || (file.extension == "aiff") || (file.extension == "wav")) {
        var fileName = file.fileName;
        var parts = fileName.split($\.);

        if(parts.size > notePosition) {
          var noteName = parts[notePosition];

          // Only show first 10 loading messages per instrument
          if(count < 10) {
            "Loading % % %".format(instrument, articulation, noteName).postln;
          };
          if(count == 10) { "... (more samples) ...".postln; };

          ~sampleManager.samples[instrument][articulation][noteName.asSymbol] =
            Buffer.read(s, file.fullPath);

          count = count + 1;
        };
      };
    };

    "Loaded % % % samples".format(count, instrument, articulation).postln;
    count;
  };

  // Play a note with specified parameters
  ~sampleManager.playNote = { |instrument, note, articulation=nil, amp=nil, pan=0, attack=nil, release=nil, out=0, callback=nil|
    var instrumentSettings, articulationToUse, noteSymbol, buffer, synth;
    var attackTime, releaseTime, ampValue, synthID;

    // Validate instrument
    instrumentSettings = ~sampleManager.instruments[instrument];
    if(instrumentSettings.isNil) {
      "Instrument % not loaded".format(instrument).warn;
      ^nil;
    };

    // Use default articulation if none specified
    articulationToUse = articulation ? instrumentSettings.defaultArticulation;

    // Convert note to symbol
    noteSymbol = note.asSymbol;

    // Get the buffer
    buffer = ~sampleManager.samples[instrument][articulationToUse][noteSymbol];
    if(buffer.isNil) {
      "Note % for % % not loaded".format(noteSymbol, instrument, articulationToUse).warn;
      ^nil;
    };

    // Set parameters based on instrument or use provided values
    attackTime = attack ? instrumentSettings.defaultAttack;
    releaseTime = release ? instrumentSettings.defaultRelease;
    ampValue = amp ? instrumentSettings.defaultAmp;

    // Create a unique synth ID for tracking
    synthID = "%.%-%-%".format(instrument, articulationToUse, noteSymbol, UniqueID.next).asSymbol;

    // Create the synth
    synth = Synth(\samplePlayer, [
      \buf, buffer,
      \amp, ampValue,
      \pan, pan,
      \attack, attackTime,
      \release, releaseTime,
      \out, out
    ]);

    // Store the synth for tracking
    ~sampleManager.activeSynths[synthID] = synth;

    // Execute callback if provided
    if(callback.notNil) {
      callback.value(synth);
    };

    // Return the synth ID for reference
    synthID;
  };

  // Play a note directly (simplified version for quick use)
  ~playNoteDirect = { |instrument, note, articulation, amp=0.7, pan=0|
    var noteSymbol = note.asSymbol;
    var buffer, attackTime, releaseTime, ampValue;

    // Get correct buffer based on instrument and articulation
    buffer = ~sampleManager.samples[instrument][articulation][noteSymbol];

    // Set parameters based on instrument
    case
      { instrument == \flute } {
        attackTime = 0.01;
        releaseTime = 0.3;
        ampValue = amp;
      }
      { instrument == \marimba } {
        attackTime = 0.005;
        releaseTime = 0.5;
        ampValue = amp;
      }
      { instrument == \piano } {
        attackTime = 0.001;
        releaseTime = 0.3;
        ampValue = amp * 3.0;
      }
      {
        attackTime = 0.01;
        releaseTime = 0.3;
        ampValue = amp;
      };

    if(buffer.notNil) {
      "Playing % % %".format(instrument, articulation, noteSymbol).postln;

      Synth(\samplePlayer, [
        \buf, buffer,
        \amp, ampValue,
        \pan, pan,
        \attack, attackTime,
        \release, releaseTime
      ]);
    } {
      "Note % for % % not loaded".format(noteSymbol, instrument, articulation).warn;
    };
  };

  // Load samples directly using loadSampleFolder
  "Loading piano samples...".postln;
  ~loadSampleFolder.(~pianoFFFolder, \piano, \ff, 2);
  s.sync;

  "Loading marimba samples...".postln;
  ~loadSampleFolder.(~marimbaCordFolder, \marimba, \cord, 3);
  s.sync;

  "Loading flute samples...".postln;
  ~loadSampleFolder.(~fluteVibFolder, \flute, \vib, 3);
  s.sync;

  // Setup reverb after samples are loaded
  "Setting up reverb effects...".postln;
  ~sampleManager.reverbBus = Bus.audio(s, 2);
  s.sync; // Make sure bus is created before making the synth

  ~sampleManager.reverbSynth = Synth(\simpleReverb, [
    \in, ~sampleManager.reverbBus,
    \out, 0,
    \mix, 0.45,
    \room, 0.6,
    \damp, 0.5
  ], addAction: \addToTail);

  "Reverb setup complete.".postln;

  // Play a note with reverb
  ~sampleManager.playNoteWithReverb = { |instrument, note, articulation=nil, dryAmp=0.7, wetAmp=0.3, pan=0|
    var directID = ~sampleManager.playNote(
      instrument, note, articulation,
      dryAmp, pan, nil, nil,
      0  // Direct to main output
    );

    // Return the ID
    directID;
  };

  // Set up piano
  ~sampleManager.instruments[\piano] = (
    name: \piano,
    articulations: [\ff],
    defaultArticulation: \ff,
    defaultAttack: 0.001,
    defaultRelease: 0.3,
    defaultAmp: 1.8
  );

  // Set up marimba
  ~sampleManager.instruments[\marimba] = (
    name: \marimba,
    articulations: [\cord],
    defaultArticulation: \cord,
    defaultAttack: 0.005,
    defaultRelease: 0.5,
    defaultAmp: 0.7
  );

  // Set up flute
  ~sampleManager.instruments[\flute] = (
    name: \flute,
    articulations: [\vib],
    defaultArticulation: \vib,
    defaultAttack: 0.01,
    defaultRelease: 0.3,
    defaultAmp: 0.6
  );

	"Instruments Initialized".postln;

  // ----- INSTRUMENT CONSTRAINTS -----

  // Add instrument specific pattern constraints
  ~stateManager.updateParam.("instrumentConstraints.patternLimits.piano", (min: 2, max: 8));  // Piano can have longer patterns
  ~stateManager.updateParam.("instrumentConstraints.patternLimits.marimba", (min: 2, max: 6));  // Medium length for marimba
  ~stateManager.updateParam.("instrumentConstraints.patternLimits.flute", (min: 1, max: 4));  // Shorter patterns for flute

  // When instruments enter in the sequence
  ~stateManager.updateParam.("instrumentConstraints.entryTimes.piano", 0);  // Start immediately
  ~stateManager.updateParam.("instrumentConstraints.entryTimes.marimba", 32);  // Enter after 32 beats
  ~stateManager.updateParam.("instrumentConstraints.entryTimes.flute", 64);  // Enter after 64 beats

  // ----- SETUP DEFAULT PRESET -----

  // Setup default timeline events
  ~defaultTimeline = [
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
      instrument: \piano,
      processType: \additive
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
      instrument: \marimba,
      processType: \additive
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
      instrument: \flute,
      processType: \additive
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
  ];

  // Setup initial musical state
  ~defaultMusicalState = (
    // Musical controls
    root: 60,                  // Middle C
    scale: \naturalMinor,      // Starting scale
    tension: 0,                // Current tension level (0-100)
    harmonicDensity: 0,        // Current harmonic density (0-100)
    rhythmicDensity: 0,        // Current rhythmic density (0-100)
    verticalSpread: 0,         // Current vertical spread (0-100)

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
  );

  // Setup default preset
  ~setupDefaultPreset = {
    // Load the default timeline
    ~timelineInterpreter.loadTimeline.(~defaultTimeline);

		"| Timeline Loaded".postln;

    // Set musical state
    ~defaultMusicalState.keysValuesDo { |key, value|
      ~stateManager.updateParam.("musical." ++ key, value);
    };

		"| Musical State Set".postln;

    // Configure audio settings
    ~stateManager.updateParam.("audio.masterVolume", 0.8);
    ~stateManager.updateParam.("audio.instrumentVolumes.piano", 0.8);
    ~stateManager.updateParam.("audio.instrumentVolumes.marimba", 0.7);
    ~stateManager.updateParam.("audio.instrumentVolumes.flute", 0.6);

    // Configure process settings
    ~stateManager.updateParam.("process.currentProcess", \additive);
    ~stateManager.updateParam.("process.additiveDuration", 128);
    ~stateManager.updateParam.("process.subtractiveDuration", 96);
    ~stateManager.updateParam.("process.transformChance", 0.15);

    ~stateManager.log.("Default preset configured");

    true;
	};

	"setting up default preset....".postln;

  // Load the default preset
  ~setupDefaultPreset.();

  // ----- SYSTEM CONTROL FUNCTIONS -----

  // Start the system
  ~startSystem = {
    // Check if already running
    var systemTempo = ~stateManager.getParam.("timing.tempo");
    if(~stateManager.state.runtime.isPlaying) {
      "System is already running.".postln;
      ^false;
    };

    // Set up clock safely
    if(systemTempo.isNil) {
      systemTempo = ~tempo;
    };
    ~clock.tempo = systemTempo / 60;

    // Mark system as running
    ~stateManager.updateParam.("runtime.isPlaying", true);
    ~stateManager.updateParam.("runtime.startTime", Date.getDate);
    ~stateManager.updateParam.("runtime.currentBeat", 0);

    // Start beat counter with instrument entries
    try {
      ~stateManager.startBeatCounter.();
    } {
      "Warning: Could not start beat counter".warn;
    };

    // Initialize pattern engine
    try {
      ~patternEngine.setupPhasePatterns.();
      ~patternEngine.setupProcessCycling.();
    } {
      "Warning: Could not setup pattern engine".warn;
    };

    // Start the timeline
    try {
      ~timelineInterpreter.start.();
    } {
      "Warning: Could not start timeline".warn;
    };

    "System started with staggered instrument entries:".postln;
    "  Piano: Beat %".format(~stateManager.getParam.("instrumentConstraints.entryTimes.piano")).postln;
    "  Marimba: Beat %".format(~stateManager.getParam.("instrumentConstraints.entryTimes.marimba")).postln;
    "  Flute: Beat %".format(~stateManager.getParam.("instrumentConstraints.entryTimes.flute")).postln;
    "Use ~stopSystem.() to stop.".postln;

    true;
  };

  // Stop the system
  ~stopSystem = {
    if(~stateManager.state.runtime.isPlaying.not) {
      "System is not running.".postln;
      ^false;
    };

    // Stop all patterns
    try {
      ~patternEngine.stopAllPatterns.();
    } {
      "Warning: Could not stop all patterns".warn;
    };

    // Stop timeline interpreter
    try {
      ~timelineInterpreter.stopTimeline.();
    } {
      "Warning: Could not stop timeline".warn;
    };

    // Stop all active routines
    try {
      ~stateManager.state.runtime.activeRoutines.do {|routine|
        if(routine.isPlaying) {
          routine.stop;
        };
      };
    } {
      "Warning: Could not stop all routines".warn;
    };

    // Clear collections
    try {
      ~stateManager.state.runtime.activeRoutines = List.new;
      ~stateManager.state.runtime.activeSynths = List.new;
    } {
      "Warning: Could not clear all collections".warn;
    };

    // Set playing state
    ~stateManager.updateParam.("runtime.isPlaying", false);
    ~stateManager.updateParam.("runtime.stopTime", Date.getDate);

    "System stopped.".postln;
    true;
  };

  // Set the tempo
  ~setTempo = {|newTempo|
    ~tempo = newTempo;
    ~clock.tempo = newTempo / 60;
    ~stateManager.updateParam.("timing.tempo", newTempo);
    "Tempo set to %".format(newTempo).postln;
  };

  // Toggle between additive and subtractive processes
  ~toggleProcess = {
    var currentProcess = ~stateManager.getParam.("process.currentProcess");
    var newProcess;

    if(currentProcess == \additive) {
      newProcess = \subtractive;
    } {
      newProcess = \additive;
    };

    ~stateManager.updateParam.("process.currentProcess", newProcess);
    "Process changed to %".format(newProcess).postln;
  };

  // Play a note with reverb
  ~playNote = {|instrument, note, dryAmp=0.7, wetAmp=0.3, pan=0|
    // Convert MIDI note to note name if needed
    if(note.isNumber) {
      try {
        note = ~musicalConstraints.noteToName.(note);
      } {
        // Simple MIDI to note name conversion
        var noteNames = #["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"];
        var noteName = noteNames[note % 12];
        var octave = (note / 12).floor - 1;
        note = noteName ++ octave.asString;
      };
    };

    // Play the note with reverb
    ~sampleManager.playNoteWithReverb.(instrument, note, nil, dryAmp, wetAmp, pan);
  };

  // Test all instruments with a simple sequence
  ~testAllInstruments = {
    Routine({
      "Testing Piano...".postln;
      ~playNoteDirect.(\piano, "C4", \ff, 0.7);
      0.5.wait;
      ~playNoteDirect.(\piano, "E4", \ff, 0.7);
      0.5.wait;
      ~playNoteDirect.(\piano, "G4", \ff, 0.7);
      1.wait;

      "Testing Marimba...".postln;
      ~playNoteDirect.(\marimba, "C4", \cord, 0.7);
      0.5.wait;
      ~playNoteDirect.(\marimba, "E4", \cord, 0.7);
      0.5.wait;
      ~playNoteDirect.(\marimba, "G4", \cord, 0.7);
      1.wait;

      "Testing Flute...".postln;
      ~playNoteDirect.(\flute, "C5", \vib, 0.7);
      0.7.wait;
      ~playNoteDirect.(\flute, "E5", \vib, 0.7);
      0.7.wait;
      ~playNoteDirect.(\flute, "G5", \vib, 0.7);

      "Test complete!".postln;
    }).play;
  };

  // Test functions
  ~testPianoPattern = {
  var pattern = [
    (note: 60, vel: 0.2, dur: 0.25),
    (note: 62, vel: 0.2, dur: 0.25),
    (note: 64, vel: 0.2, dur: 0.25),
    (note: 65, vel: 0.2, dur: 0.25)
  ];

  var routine = Routine({
    "Starting simple piano pattern test...".postln;

    inf.do {
      pattern.do { |evt|
        var note = evt[\note];
        var velocity = evt[\vel];
        var duration = evt[\dur];
        var noteName = ~musicalConstraints.noteToName.(note);

        "Playing note %".format(noteName).postln;
        ~playNoteDirect.(\piano, noteName, \ff, velocity * 0.7, 0);

        duration.wait;
      };
    };
  });

  // Store the routine so we can stop it later
  ~testRoutine = routine.play(~clock);

  "Test piano pattern started. Use ~stopTestPattern.() to stop.".postln;

  ~testRoutine;
};
  // Stop the test pattern
  ~stopTestPattern = {
    if(~testRoutine.notNil && ~testRoutine.isPlaying) {
      ~testRoutine.stop;
      ~testRoutine = nil;
      "Test pattern stopped.".postln;
    } {
      "No test pattern is currently playing.".postln;
    };
  };

  // Test basic instrument functions without patterns
  ~testBasicInstrumentFunctions = {
    Routine({
      var scale = [60, 62, 64, 65, 67, 69, 71, 72];  // C major scale

      "Testing basic instrument functionality...".postln;

      // Play C major scale on piano
      "Piano test:".postln;
      scale.do { |note|
        var noteName = ~musicalConstraints.noteToName.(note);
        "Playing % (%)".format(noteName, note).postln;
        ~playNoteDirect.(\piano, noteName, \ff, 0.7, 0);
        0.25.wait;
      };

      1.wait;

      // Play broken C major chord on marimba
      "Marimba test:".postln;
      [60, 64, 67, 64, 60].do { |note|
        var noteName = ~musicalConstraints.noteToName.(note);
        "Playing % (%)".format(noteName, note).postln;
        ~playNoteDirect.(\marimba, noteName, \cord, 0.7, 0);
        0.3.wait;
      };

      1.wait;

      // Play ascending flute notes
      "Flute test:".postln;
      [72, 74, 76, 77, 79].do { |note|
        var noteName = ~musicalConstraints.noteToName.(note);
        "Playing % (%)".format(noteName, note).postln;
        ~playNoteDirect.(\flute, noteName, \vib, 0.7, 0);
        0.4.wait;
      };

      "Basic instrument test complete.".postln;
    }).play;
  };

  // Test musical constraints
  ~testMusicalConstraints = {
    "Testing musical constraints...".postln;

    "Current root: %".format(~musicalConstraints.getRoot.()).postln;
    "Current scale: %".format(~musicalConstraints.getScaleName.()).postln;

    "Scale notes:".postln;
    ~musicalConstraints.getScaleNotes.().do { |note|
      "  % (%)".format(~musicalConstraints.noteToName.(note), note).postln;
    };

    "Changing scale to dorian...".postln;
    ~musicalConstraints.changeScale.(\dorian);

    "New scale notes:".postln;
    ~musicalConstraints.getScaleNotes.().do { |note|
      "  % (%)".format(~musicalConstraints.noteToName.(note), note).postln;
    };

    "Changing root up by 3 semitones...".postln;
    ~musicalConstraints.changeRoot.(3);

    "New root: %".format(~musicalConstraints.getRoot.()).postln;
    "New scale notes:".postln;
    ~musicalConstraints.getScaleNotes.().do { |note|
      "  % (%)".format(~musicalConstraints.noteToName.(note), note).postln;
    };

    "Musical constraints test complete.".postln;
  };

  // Print out available commands including these test functions
  ~printAdditionalCommands = {
    "=== Additional Test Commands ===".postln;
    "  ~testPianoPattern.()        - Test simple piano pattern".postln;
    "  ~stopTestPattern.()         - Stop test pattern".postln;
    "  ~testBasicInstrumentFunctions.() - Test basic instrument sounds".postln;
    "  ~testMusicalConstraints.()  - Test musical constraint functions".postln;
    "==============================".postln;
  };

  // ----- INITIALIZE SYSTEM -----

  // Print instructions
  "=== System Ready ===".postln;
  "Available commands:".postln;
  "  ~startSystem.()         - Start the system".postln;
  "  ~stopSystem.()          - Stop the system".postln;
  "  ~toggleProcess.()       - Switch between additive/subtractive".postln;
  "  ~setTempo.(120)         - Change the tempo".postln;
  "  ~playNote.(\\piano, \"C4\") - Play an individual note".postln;
  "  ~playNoteDirect.(\\piano, \"C4\", \\ff) - Play a direct note (alternative)".postln;
  "  ~testAllInstruments.()  - Test all instruments".postln;

  // Print additional test commands
  ~printAdditionalCommands.();

  "===========================".postln;
});
)

// Example usage:
// ~startSystem.();
// ~playNote.(\piano, "C4");
// ~playNoteDirect.(\piano, "C4", \ff);
// ~toggleProcess.();
// ~setTempo.(120);
// ~testAllInstruments.();
// ~stopSystem.();