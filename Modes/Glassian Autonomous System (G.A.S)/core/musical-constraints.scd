(
// musical-constraints.scd
// Module for handling scales, modes, and tension/resolution
// Provides functions for working with musical theory in the generative system

/*
  Usage:
  1. Initialize using ~musicalConstraints.init()
  2. Generate notes using ~musicalConstraints.getScaleNotes() or ~musicalConstraints.getNextNotes()
  3. Check notes using ~musicalConstraints.isValidNote()
  4. Update musical state using ~musicalConstraints.updateState()
*/

// Create namespace for musical constraints
~musicalConstraints = ();

// Initialize the module
~musicalConstraints.init = {
  // Make sure state manager is available
  if(~stateManager.isNil) {
    "Error: State Manager must be initialized before Musical Constraints".error;
    ^false;
  };

  // Initialize the last note for note sequence generation
  ~musicalConstraints.lastNote = nil;

  ~stateManager.log.("Musical Constraints module initialized");

  // Return for chaining
  ~musicalConstraints;
};

// Get the current root note
~musicalConstraints.getRoot = {
  ~stateManager.getParam.("musical.root");
};

// Get the current scale
~musicalConstraints.getScale = {
  var scaleName = ~stateManager.getParam.("musical.scale");
  ~stateManager.getParam.("scales." ++ scaleName);
};

// Get the current scale name
~musicalConstraints.getScaleName = {
  ~stateManager.getParam.("musical.scale");
};

// Generate notes in current scale
~musicalConstraints.getScaleNotes = { |numOctaves = 2, startOctave = 0|
  var root = ~musicalConstraints.getRoot.();
  var scale = ~musicalConstraints.getScale.();
  var notes = [];

  if(root.isNil || scale.isNil) {
    // Handle missing parameters
    ~stateManager.log.("Warning: Missing root or scale parameters", \warn);
    ^[60, 62, 64, 65, 67, 69, 71, 72];  // Fall back to C major
  };

  numOctaves.do({ |octave|
    scale.do({ |offset|
      notes = notes.add(root + offset + ((startOctave + octave) * 12));
    });
  });

  notes;
};

// Check if a note fits current scale
~musicalConstraints.isValidNote = { |note|
  var root = ~musicalConstraints.getRoot.();
  var scale = ~musicalConstraints.getScale.();
  var normalizedNote, inScale;

  if(root.isNil || scale.isNil) {
    // Handle missing parameters
    ~stateManager.log.("Warning: Missing root or scale parameters", \warn);
    ^true;  // Default to allowing any note
  };

  normalizedNote = (note - root) % 12;
  inScale = scale.includes(normalizedNote);

  inScale;
};

// Get weighted note probabilities based on musical state
~musicalConstraints.getNoteWeights = { |availableNotes|
  var weights = Array.fill(availableNotes.size, 1);
  var tensionPhase = ~stateManager.getParam.("musical.tension") > 50;
  var lastNote = ~musicalConstraints.lastNote;

  // Adjust weights based on tension
  weights = weights.collect({ |w, i|
    var note = availableNotes[i];
    var weight = w;

    // Favor higher notes in high tension
    if(tensionPhase) {
      weight = weight * (1 + (note - ~musicalConstraints.getRoot.())/24);
    };

    // Favor stepwise motion
    if(lastNote.notNil) {
      var interval = (note - lastNote).abs;
      weight = weight * (1 / (1 + (interval/2)));
    };

    weight;
  });

  weights;
};

// Get next suggested notes based on current state
~musicalConstraints.getNextNotes = { |numNotes = 1|
  var availableNotes = ~musicalConstraints.getScaleNotes.();
  var weights = ~musicalConstraints.getNoteWeights.(availableNotes);
  var selected = Array.new(numNotes);

  // Handle case where no notes are available
  if(availableNotes.size == 0) {
    ~stateManager.log.("Warning: No scale notes available", \warn);
    ^[60, 64, 67];  // Fall back to C major triad
  };

  numNotes.do({
    var note = availableNotes.wchoose(weights.normalizeSum);
    selected = selected.add(note);
    ~musicalConstraints.lastNote = note;
  });

  selected;
};

// Update tension based on current pattern data
~musicalConstraints.updateTension = { |patterns|
  var harmonicDensity = 0;
  var rhythmicDensity = 0;
  var verticalSpread = 0;
  var tension = 0;
  var activeNotes, totalNotes = 0, activeDurs = 0;

  // Handle empty patterns or nil input
  if(patterns.isNil || patterns.size == 0) {
    ~stateManager.updateParam.("musical.tension", 0);
    ~stateManager.updateParam.("musical.harmonicDensity", 0);
    ~stateManager.updateParam.("musical.rhythmicDensity", 0);
    ~stateManager.updateParam.("musical.verticalSpread", 0);
    ^0;
  };

  // Extract all currently playing notes from patterns
  activeNotes = patterns.collect({ |pat|
    pat.collect({ |event| event.note });
  }).flatten;

  // Update harmonic density
  harmonicDensity = (activeNotes.size / 12 * 100).clip(0, 100);

  // Update vertical spread
  if(activeNotes.size > 0) {
    var spread = activeNotes.maxItem - activeNotes.minItem;
    verticalSpread = (spread / 36 * 100).clip(0, 100);
  };

  // Update rhythmic density
  patterns.do({ |pat|
    if(pat.notNil && pat.size > 0) {
      totalNotes = totalNotes + pat.size;
      activeDurs = activeDurs + pat.sum({ |event| event.dur ? 0.25 });
    };
  });

  if(activeDurs > 0) {
    rhythmicDensity = (totalNotes / activeDurs * 25).clip(0, 100);  // Adjust factor to normalize
  };

  // Calculate overall tension
  tension = (
    (harmonicDensity * 0.4) +
    (rhythmicDensity * 0.3) +
    (verticalSpread * 0.3)
  ).clip(0, 100);

  // Update state
  ~stateManager.updateParam.("musical.harmonicDensity", harmonicDensity);
  ~stateManager.updateParam.("musical.rhythmicDensity", rhythmicDensity);
  ~stateManager.updateParam.("musical.verticalSpread", verticalSpread);
  ~stateManager.updateParam.("musical.tension", tension);

  ~stateManager.log.("Updated musical tension: %".format(tension.round(0.1)));

  tension;
};

// Change root note but maintain scale
~musicalConstraints.changeRoot = { |interval=nil|
  var currentRoot = ~musicalConstraints.getRoot.();
  var newRoot;
  var minPitch = ~stateManager.getParam.("musical.minPitch") ? 48;
  var maxPitch = ~stateManager.getParam.("musical.maxPitch") ? 84;

  if(currentRoot.isNil) {
    currentRoot = 60;  // Default to middle C
  };


  // Use provided interval or choose a pleasing interval
  if(interval.isNil) {
    interval = [3, 4, 5, 7, -2, -3].choose;
  };

  newRoot = currentRoot + interval;

  // Keep within reasonable range
  newRoot = newRoot.clip(minPitch, maxPitch - 12);

  // Update state
  ~stateManager.updateParam.("musical.root", newRoot);

  ~stateManager.log.("Root changed to %".format(~stateManager.noteToName.(newRoot)));

  newRoot;
};

// Change scale/mode but maintain root
~musicalConstraints.changeScale = { |newScale=nil|
  var scaleNames = ~stateManager.getParam.("scales").keys.asArray;
  var currentScale = ~musicalConstraints.getScaleName.();

  if(currentScale.isNil) {
    currentScale = \major;  // Default to major scale
  };

  // Use provided scale or choose one different from current
  if(newScale.isNil) {
    // Remove current scale from choices if we have more than one scale
    if(scaleNames.size > 1) {
      scaleNames = scaleNames.reject({ |sc| sc == currentScale });
    };
    newScale = scaleNames.choose;
  };

  // Make sure the scale exists
  if(~stateManager.getParam.("scales." ++ newScale).isNil) {
    ~stateManager.log.("Warning: Scale % not found".format(newScale), \warn);
    ^currentScale;  // Keep current scale
  };

  // Update state
  ~stateManager.updateParam.("musical.scale", newScale);

  ~stateManager.log.("Scale changed to %".format(newScale));

  newScale;
};

// Invert a pattern (upside down)
~musicalConstraints.invertPattern = { |pattern|
  var center = ~musicalConstraints.getRoot.(); // Use root as center
  var result = pattern.collect({ |event|
    var invertedNote = center + (center - event.note);
    var minPitch = ~stateManager.getParam.("musical.minPitch") ? 48;
    var maxPitch = ~stateManager.getParam.("musical.maxPitch") ? 84;

    // Keep in reasonable range
    invertedNote = invertedNote.clip(minPitch, maxPitch);

    // Ensure the note is in the current scale
    if(~musicalConstraints.isValidNote.(invertedNote).not) {
      invertedNote = ~musicalConstraints.getNextNotes.(1)[0];
    };

    event.copy.put(\note, invertedNote);
  });

  result;
};

// Retrograde a pattern (backwards)
~musicalConstraints.retrogradePattern = { |pattern|
  pattern.reverse;
};

// Transpose a pattern
~musicalConstraints.transposePattern = { |pattern, interval|
  var result = pattern.collect({ |event|
    var newNote = event.note + interval;
    var minPitch = ~stateManager.getParam.("musical.minPitch") ? 48;
    var maxPitch = ~stateManager.getParam.("musical.maxPitch") ? 84;

    // Keep in reasonable range
    newNote = newNote.clip(minPitch, maxPitch);

    // Ensure the note is in the current scale
    if(~musicalConstraints.isValidNote.(newNote).not) {
      // Find nearest scale note
      var scale = ~musicalConstraints.getScale.();
      var root = ~musicalConstraints.getRoot.();
      var normalized = (newNote - root) % 12;
      var distances = scale.collect({ |sc| (sc - normalized).abs });
      var idx = distances.minIndex;

      if(idx.notNil && scale[idx].notNil) {
        newNote = newNote + (scale[idx] - normalized);
      } {
        // Fall back to a note from the scale
        newNote = ~musicalConstraints.getNextNotes.(1)[0];
      };
    };

    event.copy.put(\note, newNote);
  });

  result;
};

// Convert MIDI note to note name
~musicalConstraints.noteToName = { |note|
  var noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
  var octave = (note / 12).floor - 1;
  var noteName = noteNames[note % 12];
  noteName ++ octave.asString;
};

// Convert note name to MIDI note
~musicalConstraints.nameToNote = { |noteName|
  var noteMap, octave, note;

  // Handle different note name formats
  if(noteName.isString || noteName.isSymbol) {
    var nameStr = noteName.asString;
    var lastChar = nameStr.last;
    var nameWithoutOctave, octaveChar;

    // Check if the last character is a digit
    if(lastChar.isDecDigit) {
      octaveChar = lastChar;
      nameWithoutOctave = nameStr.drop(-1);
    } {
      // Default to octave 4 if not specified
      octaveChar = "4";
      nameWithoutOctave = nameStr;
    };

    // Set up note name mapping
    noteMap = Dictionary[
      'C' -> 0, 'C#' -> 1, 'Db' -> 1,
      'D' -> 2, 'D#' -> 3, 'Eb' -> 3,
      'E' -> 4, 'F' -> 5, 'F#' -> 6,
      'Gb' -> 6, 'G' -> 7, 'G#' -> 8,
      'Ab' -> 8, 'A' -> 9, 'A#' -> 10,
      'Bb' -> 10, 'B' -> 11
    ];

    // Calculate the MIDI note number
    note = noteMap[nameWithoutOctave.asSymbol];
    if(note.isNil) {
      ~stateManager.log.("Warning: Invalid note name: %".format(nameWithoutOctave), \warn);
      ^60;  // Default to middle C if invalid
    };

    octave = octaveChar.asString.asInteger;
    note = note + ((octave + 1) * 12);
  } {
    // Assume it's already a MIDI note number
    note = noteName.asInteger;
  };

  note;
};

"Musical Constraints module loaded successfully.".postln;
~musicalConstraints;
)