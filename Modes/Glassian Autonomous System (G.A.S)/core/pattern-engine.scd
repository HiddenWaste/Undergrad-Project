// pattern-engine.scd
// Pattern generation and evolution for the Glass-inspired system
// Handles creating, transforming, and playing musical patterns

/*
  Usage:
  1. Initialize using ~patternEngine.init()
  2. Generate patterns using ~patternEngine.generatePattern()
  3. Evolve patterns using ~patternEngine.evolvePattern()
  4. Start pattern playback using ~patternEngine.startPattern()
*/

(
// Create namespace for the pattern engine
~patternEngine = ();

// Initialize the pattern engine
~patternEngine.init = {
  // Make sure dependencies are available
  if(~stateManager.isNil) {
    "Error: State Manager must be initialized before Pattern Engine".error;
    ^false;
  };

  if(~musicalConstraints.isNil) {
    "Error: Musical Constraints must be initialized before Pattern Engine".error;
    ^false;
  };

  // Initialize storage for active patterns
  ~patternEngine.activePatterns = Dictionary.new;
  ~patternEngine.patternData = Dictionary.new;
  ~patternEngine.phaseRoutine = nil;
  ~patternEngine.processCycleRoutine = nil;

  ~stateManager.log.("Pattern Engine initialized");

  // Return for chaining
  ~patternEngine;
};

// Format pattern for display
~patternEngine.formatPattern = { |pattern, label="Pattern"|
  var result = "";
  result = result ++ "=== % ===\n".format(label);

  pattern.do { |evt, i|
    result = result ++ "  [%] % (vel: %, dur: %)\n".format(
      i,
      ~musicalConstraints.noteToName.(evt.note),
      evt.vel.round(0.01),
      evt.dur
    );
  };

  result = result ++ "==============";
  ~stateManager.log.(result);

  result;
};

// Generate a new pattern for an instrument
~patternEngine.generatePattern = { |instrument, length=nil, style=\basic|
  var pattern = List.new;
  var instrumentKey = instrument.asSymbol;
  var constraints = ~stateManager.getParam.("instrumentConstraints.patternLimits." ++ instrumentKey);
  var minLength, maxLength;

  // Use instrument-specific constraints or defaults
  if(constraints.notNil) {
    minLength = constraints.min;
    maxLength = constraints.max;
  } {
    minLength = ~stateManager.getParam.("process.minPatternLength");
    maxLength = ~stateManager.getParam.("process.maxPatternLength");
  };

  // Use specified length or pick between min/max
  if(length.isNil) {
    length = rrand(minLength, maxLength);
  } {
    // Ensure length is within constraints
    length = length.clip(minLength, maxLength);
  };

  // Create a pattern of proper length
  length.do({ |i|
    var noteChoices = ~musicalConstraints.getNextNotes.(1);
    var note = noteChoices[0];
    var velocity = rrand(0.15, 0.25);
    var duration, noteEvent;

    // Duration based on style
    duration = case
      { style == \minimal } { 0.25 }
      { style == \melodic } { 0.5 }
      { 0.25 };

    noteEvent = (
      note: note,
      vel: velocity,
      dur: duration
    );
    // Create the note event

    pattern.add(noteEvent);
  });

  // Log the new pattern
  ~patternEngine.formatPattern.(pattern.asArray, "Generated % Pattern".format(instrumentKey));
  ~stateManager.log.("Generated % pattern with % notes (limits: % to %)".format(
    instrumentKey, pattern.size, minLength, maxLength
  ));

  // Return the array version of the pattern
  pattern.asArray;
};

// Display pattern information
~patternEngine.logPattern = { |instrument, pattern, operation="No change", beatPosition=nil|
  var noteInfo = pattern.collect({ |n, i|
    "    [%] % (vel: %, dur: %)".format(
      i,
      ~musicalConstraints.noteToName.(n.note),
      n.vel.round(0.01),
      n.dur
    )
  });

  // Format beat position if provided
  var beatInfo = if(beatPosition.notNil) {
    " at beat %".format(beatPosition.round(0.1))
  } {
    ""
  };

  "=== Pattern Change% ===".format(beatInfo).postln;
  ("Instrument: " ++ instrument).postln;
  ("Operation: " ++ operation).postln;
  "Notes:".postln;
  noteInfo.do({ |info| info.postln });
  "".postln;

  // Also log to state manager
  ~stateManager.log.("Pattern change for %: %".format(instrument, operation));
};

// Enhanced evolve pattern function with detailed output
~patternEngine.evolvePattern = { |currentPattern, instrument|
  var newPattern = currentPattern.copy;
  var instrumentKey = instrument.asSymbol;
  var constraints = ~stateManager.getParam.("instrumentConstraints.patternLimits." ++ instrumentKey);
  var isAdditive = ~stateManager.getParam.("process.currentProcess") == \additive;
  var minLength, maxLength;
  var operation = "No change";
  var changesMade = false;

  // Get musical tension level
  var tension = ~stateManager.getParam.("musical.tension");
  var tensionThreshold = ~stateManager.getParam.("musical.tensionThreshold");
  var modeChangeThreshold = ~stateManager.getParam.("musical.modeChangeThreshold");

  var velocityChangeChance, rhythmChangeChance;

  // Use instrument-specific constraints or defaults
  if(constraints.notNil) {
    minLength = constraints.min;
    maxLength = constraints.max;
  } {
    minLength = ~stateManager.getParam.("process.minPatternLength");
    maxLength = ~stateManager.getParam.("process.maxPatternLength");
  };

  // Display original pattern
  "=== Pattern Evolution (%) ===".format(instrumentKey).postln;
  "Current process: % (limits: % to %)".format(
    ~stateManager.getParam.("process.currentProcess"),
    minLength,
    maxLength
  ).postln;
  ~patternEngine.formatPattern.(currentPattern, "Original Pattern");

  // Update musical state based on all current patterns
  ~musicalConstraints.updateTension.(~patternEngine.patternData.values.asArray);


  // Handle tension-based transformations
  if(tension > tensionThreshold) {
    // Increase chance of transformation
    var transformChance = ~stateManager.getParam.("process.transformChance") * 1.5;

    // Consider mode change if tension is very high
    if(tension > modeChangeThreshold && 0.3.coin) {
      ~musicalConstraints.changeScale.();
      operation = "Scale changed due to high tension";
      changesMade = true;
    } {
      if(transformChance.coin) {
        // Apply a random transformation
        var transform = [\invert, \retrograde, \transpose].choose;

        case
          { transform == \invert } {
            newPattern = ~musicalConstraints.invertPattern.(newPattern);
            operation = "Pattern inverted";
            changesMade = true;
          }
          { transform == \retrograde } {
            newPattern = ~musicalConstraints.retrogradePattern.(newPattern);
            operation = "Pattern retrograded";
            changesMade = true;
          }
          { transform == \transpose } {
            var interval = [-7, -5, -3, 3, 5, 7].choose;
            newPattern = ~musicalConstraints.transposePattern.(newPattern, interval);
            operation = "Pattern transposed by %".format(interval);
            changesMade = true;
          };
      };
    };
  };

  // Handle additive/subtractive processes
  if(isAdditive) {
    if(currentPattern.size < maxLength) {
      var nextNotes = ~musicalConstraints.getNextNotes.(1);
      var nextNote = (
        note: nextNotes[0],
        vel: rrand(0.15, 0.25),
        dur: [0.25, 0.5].choose
      );

      newPattern = newPattern ++ [nextNote];
      operation = operation ++ (if(changesMade) { " + " } { "" }) ++
                  "Added note %".format(~musicalConstraints.noteToName.(nextNotes[0]));
      changesMade = true;
    };
  } {
    if(currentPattern.size > minLength) {
      var removedNote = newPattern.last.note;
      newPattern = newPattern.drop(-1);
      operation = operation ++ (if(changesMade) { " + " } { "" }) ++
                  "Removed note %".format(~musicalConstraints.noteToName.(removedNote));
      changesMade = true;
    };
  };

  // Velocity evolution
  velocityChangeChance = ~stateManager.getParam.("musical.velocityChangeChance");

  if(velocityChangeChance.coin) {
    var idx = rrand(0, newPattern.size - 1);
    var oldVel = newPattern[idx].vel;
    var newVel = rrand(0.15, 0.25);

    newPattern[idx].vel = newVel;
    operation = operation ++ (if(changesMade) { " + " } { "" }) ++
                "Changed velocity of note % [%] from % to %".format(
                  idx,
                  ~musicalConstraints.noteToName.(newPattern[idx].note),
                  oldVel.round(0.01),
                  newVel.round(0.01)
                );
    changesMade = true;
  };

  // Rhythm evolution
  rhythmChangeChance = ~stateManager.getParam.("musical.rhythmChangeChance");

  if(rhythmChangeChance.coin) {
    var idx = rrand(0, newPattern.size - 1);
    var oldDur = newPattern[idx].dur;
    var newDur = [0.25, 0.5].choose;

    // Only change if the new duration is different
    if(oldDur != newDur) {
      newPattern[idx].dur = newDur;
      operation = operation ++ (if(changesMade) { " + " } { "" }) ++
                  "Changed duration of note % [%] from % to %".format(
                    idx,
                    ~musicalConstraints.noteToName.(newPattern[idx].note),
                    oldDur,
                    newDur
                  );
      changesMade = true;
    };
  };

  // If no changes were made, keep the operation as "No change"
  if(changesMade.not) {
    operation = "No change";
  };

  // Display results
  "Operation: %".format(operation).postln;
  ~patternEngine.formatPattern.(newPattern, "Updated Pattern");
  "==============================".postln;

  [newPattern, operation, changesMade];
};

// Start playing a pattern for an instrument
~patternEngine.startPattern = { |instrument, pattern, processType=nil|
  var instrumentKey = instrument.asSymbol;
  var routine, player;

  // Use provided pattern or generate a new one
  pattern = pattern ?? { ~patternEngine.generatePattern.(instrumentKey) };

  // Store pattern data
  ~patternEngine.patternData[instrumentKey] = pattern;

  // Set current process type if provided
  if(processType.notNil) {
    ~stateManager.updateParam.("process.currentProcess", processType);
  };

  // Create a routine to play the pattern
  routine = Routine({
    var currentProcess, evolveRate, transformChance;
    var beatCount = 0;

    inf.do {
      // Get current state values
      currentProcess = ~stateManager.getParam.("process.currentProcess");

      // Determine evolution rate based on process
      evolveRate = if(currentProcess == \additive) {
        ~stateManager.getParam.("process.additionRate") ? 16
      } {
        ~stateManager.getParam.("process.subtractionRate") ? 24
      };

      // Check if it's time to evolve the pattern
      if(beatCount % evolveRate == 0 && beatCount > 0) {
        var currentPattern = ~patternEngine.patternData[instrumentKey];
        var result = ~patternEngine.evolvePattern.(currentPattern, instrumentKey);
        var newPattern = result[0];
        var operation = result[1];
        var changed = result[2];

        // Update pattern if it changed
        if(changed) {
          ~patternEngine.patternData[instrumentKey] = newPattern;
          ~patternEngine.updatePattern.(instrumentKey, newPattern);

          // Log the evolution
          ~stateManager.log.("Evolved % pattern: %".format(instrumentKey, operation));
        };
      };

      // Get the current pattern (which might have been updated)
      pattern = ~patternEngine.patternData[instrumentKey];

      // Play each note in the pattern
      pattern.do { |evt|
        var note = evt.note;
        var velocity = evt.vel;
        var duration = evt.dur;
        var articulation, amp, pan;

        // Determine articulation based on instrument
        articulation = case
          { instrumentKey == \piano } { \ff }
          { instrumentKey == \marimba } { \cord }
          { instrumentKey == \flute } { \vib }
          { nil };

        // Calculate amplitude based on velocity
        amp = velocity * (~stateManager.getParam.("audio.instrumentVolumes." ++ instrumentKey) ? 0.7);

        // Calculate pan based on instrument
        pan = ~stateManager.getParam.("audio.instrumentPans." ++ instrumentKey) ? 0;

        // Play the note
        ~playNoteDirect.(instrumentKey, ~musicalConstraints.noteToName.(note), articulation, amp, pan);

        // Wait for the note duration
        duration.wait;
      };

      // Increment beat counter
      beatCount = beatCount + 1;
    };
  });

  // Start the routine
  player = routine.play(~stateManager.clock);

  // Store active pattern for later reference
  ~patternEngine.activePatterns[instrumentKey] = player;

  // Add to active routines for cleanup
  ~stateManager.state.runtime.activeRoutines.add(player);

  ~stateManager.log.("Started pattern for %".format(instrumentKey));

  player;
};

// Stop a pattern for an instrument
~patternEngine.stopPattern = { |instrument|
  var instrumentKey = instrument.asSymbol;
  var player = ~patternEngine.activePatterns[instrumentKey];

  if(player.notNil && player.isPlaying) {
    player.stop;
    ~patternEngine.activePatterns.removeAt(instrumentKey);
    ~stateManager.log.("Stopped pattern for %".format(instrumentKey));
  } {
    ~stateManager.log.("No active pattern for %".format(instrumentKey));
  };

  true;
};

// Stop all active patterns
~patternEngine.stopAllPatterns = {
  ~patternEngine.activePatterns.keysValuesDo { |instrument, player|
    if(player.isPlaying) {
      player.stop;
      ~stateManager.log.("Stopped pattern for %".format(instrument));
    };
  };

  ~patternEngine.activePatterns = Dictionary.new;
  ~stateManager.log.("All patterns stopped");

  true;
};

// Update a pattern while it's playing (for transitions)
~patternEngine.updatePattern = { |instrument, newPattern|
  var instrumentKey = instrument.asSymbol;

  // Update the stored pattern data
  ~patternEngine.patternData[instrumentKey] = newPattern;

  // Log the update
  ~patternEngine.logPattern.(instrumentKey, newPattern, "Pattern updated",
    ~stateManager.getParam.("runtime.currentBeat"));

  true;
};

// Setup phase relationships between patterns
~patternEngine.setupPhasePatterns = { |force=false|
  var phaseSettings = ~stateManager.getParam.("patterns.phasing.primary");

  // Skip if already defined and not forced to redefine
  if(~patternEngine.phaseRoutine.notNil && ~patternEngine.phaseRoutine.isPlaying && force.not) {
    ~stateManager.log.("Phase patterns already running");
    ^~patternEngine.phaseRoutine;
  };

  if(phaseSettings.isNil || phaseSettings.active.not) {
    ~stateManager.log.("No phase settings found or phases inactive");
    ^false;
  };

  // Create a routine to apply phase shifts
  ~patternEngine.phaseRoutine = Routine({
    var shiftEvery = phaseSettings.shiftEvery ? 32;
    var instruments = phaseSettings.instruments ? [\piano, \marimba, \flute];
    var phaseShift = phaseSettings.phaseShift ? (1/8);
    var staggered = phaseSettings.staggered ? true;
    var beatCount = 0;

    ~stateManager.log.("Starting phase shifting routine");

    inf.do {
      // Check if it's time to apply phase shifts
      if(beatCount % shiftEvery == 0 && beatCount > 0) {
        ~stateManager.log.("Applying phase shifts at beat %".format(beatCount));

        // Apply phase shifts to each instrument
        instruments.do { |instrumentKey, i|
          var currentPattern = ~patternEngine.patternData[instrumentKey];

          if(currentPattern.notNil && currentPattern.size > 1) {
            // Apply phase shift based on instrument index
            var shift = if(staggered) {
              i * phaseShift
            } {
              phaseShift
            };

            // Phase shifting is implemented by reordering the pattern
            if(shift > 0) {
              var shiftItems = (currentPattern.size * shift).asInteger;
              if(shiftItems > 0) {
                var newPattern = currentPattern.rotate(shiftItems);

                // Update the pattern
                ~patternEngine.patternData[instrumentKey] = newPattern;
                ~patternEngine.logPattern.(instrumentKey, newPattern,
                  "Phase shifted by %".format(shift), beatCount);
              };
            };
          };
        };
      };

      // Wait one beat
      1.wait;
      beatCount = beatCount + 1;
    };
  });

  // Start the phase routine
  ~patternEngine.phaseRoutine.play(~stateManager.clock);
  ~stateManager.state.runtime.activeRoutines.add(~patternEngine.phaseRoutine);

  ~stateManager.log.("Phase relationships setup");

  ~patternEngine.phaseRoutine;
};

// Setup process cycling (additive/subtractive)
~patternEngine.setupProcessCycling = { |force=false|
  var additiveDuration = ~stateManager.getParam.("process.additiveDuration") ? 128;
  var subtractiveDuration = ~stateManager.getParam.("process.subtractiveDuration") ? 96;

  // Skip if already defined and not forced to redefine
  if(~patternEngine.processCycleRoutine.notNil && ~patternEngine.processCycleRoutine.isPlaying && force.not) {
    ~stateManager.log.("Process cycling already running");
    ^~patternEngine.processCycleRoutine;
  }
};
  // Add these functions to complete the pattern-engine.scd file

// Initialize patterns for multiple instruments
~patternEngine.initializePatterns = { |instruments=nil|
  var instrumentList = instruments ?? { [\piano, \marimba, \flute] };

  instrumentList.do { |instrument|
    var initialPattern = ~patternEngine.generatePattern.(instrument);
    ~patternEngine.patternData[instrument] = initialPattern;
  };

  ~stateManager.log.("Initialized patterns for % instruments".format(instrumentList.size));

  ~patternEngine.patternData;
};

// Generate pattern variations based on existing patterns
~patternEngine.generateVariation = { |sourcePattern, variationAmount=0.3|
  var newPattern = sourcePattern.copy;
  var numChanges = (sourcePattern.size * variationAmount).asInteger.max(1);

  numChanges.do {
    var changeType = [\changeNote, \changeVelocity, \changeDuration].choose;
    var idx = rrand(0, newPattern.size-1);

    case
      { changeType == \changeNote } {
        var noteChoices = ~musicalConstraints.getNextNotes.(1);
        newPattern[idx].note = noteChoices[0];
      }
      { changeType == \changeVelocity } {
        var minVel = ~stateManager.getParam.("musical.velocityMin") ? 0.1;
        var maxVel = ~stateManager.getParam.("musical.velocityMax") ? 0.7;
        newPattern[idx].vel = rrand(minVel, maxVel);
      }
      { changeType == \changeDuration } {
        var durations = [0.125, 0.25, 0.375, 0.5, 0.75, 1.0];
        newPattern[idx].dur = durations.choose;
      };
  };

  newPattern;
};

// Find relationships between patterns
~patternEngine.findPatternRelationships = {
  var instruments = ~patternEngine.patternData.keys.asArray;
  var relationships = List.new;

  // Check each pair of instruments
  instruments.do { |instrument1, i|
    instruments[(i+1)..].do { |instrument2|
      var pattern1 = ~patternEngine.patternData[instrument1];
      var pattern2 = ~patternEngine.patternData[instrument2];
      var relationship = ();
      var rhythmSimilarity = pattern1.collect(_.dur).normalizeSum - pattern2.collect(_.dur).normalizeSum;
      var noteDifferences = pattern1.collect(_.note).differentiate.abs -pattern2.collect(_.note).differentiate.abs;
      var pitchRelationship = noteDifferences.mean;

      // Skip if any pattern is missing
			if(pattern1.isNil || pattern2.isNil) { nil };

      // Calculate rhythmic similarity
      rhythmSimilarity = 1 - rhythmSimilarity.abs.sum;

      // Calculate pitch relationship


      // Store relationship data
      relationship = (
        source: instrument1,
        target: instrument2,
        rhythmicSimilarity: rhythmSimilarity,
        pitchRelationship: pitchRelationship
      );

      relationships.add(relationship);
    };
  };

  relationships.asArray;
};

// Create a new pattern with influences from another pattern
~patternEngine.createInfluencedPattern = { |targetInstrument, sourceInstrument, influenceAmount=0.5|
  var targetPattern = ~patternEngine.patternData[targetInstrument];
  var sourcePattern = ~patternEngine.patternData[sourceInstrument];
  var newPattern;

  // Return original pattern if source or target missing
  if(targetPattern.isNil || sourcePattern.isNil) {
    ~stateManager.log.("Warning: Missing pattern for influence operation", \warn);
    ^targetPattern;
  };

  // Create new pattern by combining elements
  newPattern = targetPattern.collect { |event, i|
    var sourceIdx = i % sourcePattern.size;
    var sourceEvent = sourcePattern[sourceIdx];
    var resultEvent = event.copy;

    // Apply rhythmic influence
    if(influenceAmount.coin) {
      resultEvent.dur = sourceEvent.dur;
    };

    // Apply velocity influence (with partial influence)
    resultEvent.vel = (event.vel * (1-influenceAmount)) + (sourceEvent.vel * influenceAmount);

    // Occasionally apply melodic influence
    if((influenceAmount * 0.5).coin) {
      var interval = sourceEvent.note - sourcePattern[0].note;
      resultEvent.note = targetPattern[0].note + interval;

      // Ensure the note is in scale
      if(~musicalConstraints.isValidNote.(resultEvent.note).not) {
        var noteChoices = ~musicalConstraints.getNextNotes.(1);
        resultEvent.note = noteChoices[0];
      };
    };

    resultEvent;
  };

  ~stateManager.log.("Created pattern for % influenced by % (amount: %)".format(
    targetInstrument, sourceInstrument, influenceAmount
  ));

  newPattern;
};

// Reset all patterns to simpler versions
~patternEngine.resetPatterns = {
  var instruments = ~patternEngine.patternData.keys.asArray;

  instruments.do { |instrument|
    var newPattern = ~patternEngine.generatePattern.(instrument, nil, \minimal);
    ~patternEngine.patternData[instrument] = newPattern;
    ~patternEngine.updatePattern.(instrument, newPattern);
  };

  ~stateManager.log.("Reset all patterns to minimal versions");

  true;
};

// Save current pattern state
~patternEngine.savePatternState = { |name="snapshot"|
  var snapshot = ();
  var instruments = ~patternEngine.patternData.keys.asArray;

  instruments.do { |instrument|
    snapshot[instrument] = ~patternEngine.patternData[instrument].copy;
  };

  ~patternEngine.patternSnapshots = ~patternEngine.patternSnapshots ?? {Dictionary.new};
  ~patternEngine.patternSnapshots[name] = snapshot;

  ~stateManager.log.("Saved pattern snapshot '%'".format(name));

  name;
};

// Restore pattern state from saved snapshot
~patternEngine.restorePatternState = { |name="snapshot"|
  var snapshot = ~patternEngine.patternSnapshots[name];

  if(snapshot.isNil) {
    ~stateManager.log.("Warning: Pattern snapshot '%' not found".format(name), \warn);
    ^false;
  };

  snapshot.keysValuesDo { |instrument, pattern|
    ~patternEngine.patternData[instrument] = pattern.copy;
    ~patternEngine.updatePattern.(instrument, pattern);
  };

  ~stateManager.log.("Restored pattern snapshot '%'".format(name));

  true;
};
)