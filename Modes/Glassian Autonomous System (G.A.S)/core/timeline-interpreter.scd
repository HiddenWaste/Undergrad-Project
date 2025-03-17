// timeline-interpreter.scd
// Timeline event interpreter for the Glass-inspired system
// Handles loading, parsing, and executing timeline events

/*
  Usage:
  1. Initialize using ~timelineInterpreter.init()
  2. Load a timeline using ~timelineInterpreter.loadTimeline(events)
  3. Start the system with timeline using ~timelineInterpreter.start()
*/

(
// Create namespace for the timeline interpreter
~timelineInterpreter = ();

// Initialize the timeline interpreter
~timelineInterpreter.init = {
  // Make sure dependencies are available
  if(~stateManager.isNil) {
    "Error: State Manager must be initialized before Timeline Interpreter".error;
    ^false;
  };

  if(~patternEngine.isNil) {
    "Error: Pattern Engine must be initialized before Timeline Interpreter".error;
    ^false;
  };

  // Initialize event queue and timeline data
  ~timelineInterpreter.eventQueue = PriorityQueue.new;
  ~timelineInterpreter.timelineData = List.new;
  ~timelineInterpreter.sectionMarkers = Dictionary.new;
  ~timelineInterpreter.repeatSections = Dictionary.new;
  ~timelineInterpreter.activeRoutines = List.new;

  ~stateManager.log.("Timeline Interpreter initialized");

  // Return for chaining
  ~timelineInterpreter;
};

// Load a timeline from a collection of events
~timelineInterpreter.loadTimeline = { |events|
  // Check if events is an array or list
  if(events.isArray.not && events.isKindOf(List).not) {
    ~stateManager.log.("Error: Events must be an array or list, not %".format(events.class), \error);
    ^false;
  };

  // Clear existing timeline
  ~timelineInterpreter.timelineData = List.new;
  ~timelineInterpreter.sectionMarkers = Dictionary.new;

  // Add each event to the timeline
  events.do { |event|
    // Skip if event is not an event (e.g., if it's a function)
    if(event.isKindOf(Event).not && event.isKindOf(IdentityDictionary).not) {
      ~stateManager.log.("Warning: Skipping non-event item: %".format(event), \warn);
    };

    ~timelineInterpreter.timelineData.add(event);

    // Register section markers
    if(event[\type] == \sectionMarker && event[\name].notNil) {
      ~timelineInterpreter.sectionMarkers[event[\name].asSymbol] = event[\beat];
    };
  };

  // Sort events by beat
  ~timelineInterpreter.timelineData = ~timelineInterpreter.timelineData.sort({ |a, b|
    a[\beat] < b[\beat]
  });

  ~stateManager.log.("Loaded timeline with % events".format(events.size));

  // Return the sorted timeline data
  ~timelineInterpreter.timelineData;
};

// Prepare the event queue for playback
~timelineInterpreter.prepareQueue = {
  // Clear the existing queue
  ~timelineInterpreter.eventQueue.clear;

  // Add all events to the queue
  ~timelineInterpreter.timelineData.do { |event|
    // Use bracket notation instead of dot notation
    ~timelineInterpreter.eventQueue.put(event[\beat], event);
  };

  ~stateManager.log.("Prepared event queue with % events".format(~timelineInterpreter.eventQueue.size));

  // Return the queue size
  ~timelineInterpreter.eventQueue.size;
};

// Start timeline execution
~timelineInterpreter.start = {
  // Make sure system is prepared
  if(~stateManager.state.runtime.isPlaying.not) {
    "Error: System must be running before starting timeline".error;
    ^false;
  };

  // Reset beat counter
  ~stateManager.updateParam.("runtime.currentBeat", 0);

  // Prepare event queue
  ~timelineInterpreter.prepareQueue.();

  // Start the execution routine
  ~timelineInterpreter.executeRoutine = Routine({
    var currentBeat, nextEventBeat, nextEvent;

    inf.do {
      currentBeat = ~stateManager.getParam.("runtime.currentBeat");

      // Check for events at this beat
      while({
        nextEventBeat = ~timelineInterpreter.eventQueue.topPriority;
        nextEventBeat.notNil && (nextEventBeat <= currentBeat);
      }, {
        nextEvent = ~timelineInterpreter.eventQueue.pop;

        // Execute the event
        ~timelineInterpreter.executeEvent.(nextEvent);
      });

      1.wait;  // Wait one beat
    };
  });

  // Start the routine
  ~timelineInterpreter.executeRoutine.play(~stateManager.clock);
  ~stateManager.state.runtime.activeRoutines.add(~timelineInterpreter.executeRoutine);

  ~stateManager.log.("Timeline execution started");

  true;
};

// Stop timeline execution (renamed to avoid conflict with built-in method)
~timelineInterpreter.stopTimeline = {
  // Stop execution routine
  if(~timelineInterpreter.executeRoutine.notNil && ~timelineInterpreter.executeRoutine.isPlaying) {
    ~timelineInterpreter.executeRoutine.stop;
    ~timelineInterpreter.executeRoutine = nil;
  };

  // Stop all active routines
  ~timelineInterpreter.activeRoutines.do { |routine|
    if(routine.isPlaying) {
      routine.stop;
    };
  };
  ~timelineInterpreter.activeRoutines = List.new;

  ~stateManager.log.("Timeline execution stopped");

  true;
};

// Execute a timeline event
~timelineInterpreter.executeEvent = { |event|
  var eventType = event[\type];  // Use array syntax instead of dot syntax

  // Log event execution
  ~stateManager.log.("Executing timeline event: % at beat %"
    .format(eventType, ~stateManager.getParam.("runtime.currentBeat")));

  // Process event based on type
  case
    // Section markers
    { eventType == \sectionMarker } {
      ~stateManager.updateParam.("runtime.currentSection", event[\name]);
      ~stateManager.log.("Entered section: %".format(event[\name]));
    }

    // Section jumps
    { eventType == \sectionJump } {
      var targetBeat = ~timelineInterpreter.sectionMarkers[event[\section].asSymbol];
      if(targetBeat.notNil) {
        ~stateManager.updateParam.("runtime.currentBeat", targetBeat);
        ~stateManager.log.("Jumped to section: % (beat %)".format(event[\section], targetBeat));

        // Reprepare the queue for events after this point
        ~timelineInterpreter.prepareQueue.();
      } {
        ~stateManager.log.("Error: Unknown section: %".format(event[\section]), \error);
      };
    }

    // Process changes
    { eventType == \processChange } {
      ~stateManager.updateParam.("process.currentProcess", event[\process]);
      ~stateManager.log.("Process changed to: %".format(event[\process]));
    }

    // Instrument start
    { eventType == \instrumentStart } {
      var instrument = event[\instrument];
      var processType = event[\processType] ? ~stateManager.getParam.("process.currentProcess");

      // Generate initial pattern
      var pattern = ~patternEngine.generatePattern.(instrument);

      // Start pattern playback
      ~patternEngine.startPattern.(instrument, pattern, processType);

      // Mark instrument as enabled
      ~stateManager.updateParam.("patterns.instrumentEnabled." ++ instrument, true);

      ~stateManager.log.("Started instrument: %".format(instrument));
    }

    // Instrument stop
    { eventType == \instrumentStop } {
      var instrument = event[\instrument];

      // Stop pattern playback
      ~patternEngine.stopPattern.(instrument);

      // Mark instrument as disabled
      ~stateManager.updateParam.("patterns.instrumentEnabled." ++ instrument, false);

      ~stateManager.log.("Stopped instrument: %".format(instrument));
    }

    // Scale changes
    { eventType == \scaleChange } {
      ~musicalConstraints.changeScale.(event[\scale]);
      ~stateManager.log.("Scale changed to: %".format(event[\scale]));
    }

    // Root changes
    { eventType == \rootChange } {
      var interval = event[\interval] ? 0;
      ~musicalConstraints.changeRoot.(interval);
      ~stateManager.log.("Root changed by interval: %".format(interval));
    }

    // Pattern transformations
    { eventType == \patternTransform } {
      var instrument = event[\instrument];
      var transform = event[\transform];
      var currentPattern, newPattern;

      // Get current pattern
      currentPattern = ~patternEngine.patternData[instrument.asSymbol];

      if(currentPattern.notNil) {
        case
          { transform == \invert } {
            newPattern = ~musicalConstraints.invertPattern.(currentPattern);
            ~stateManager.log.("Inverted pattern for %".format(instrument));
          }
          { transform == \retrograde } {
            newPattern = ~musicalConstraints.retrogradePattern.(currentPattern);
            ~stateManager.log.("Retrograded pattern for %".format(instrument));
          }
          { transform == \transpose } {
            var interval = event[\interval] ? 0;
            newPattern = ~musicalConstraints.transposePattern.(currentPattern, interval);
            ~stateManager.log.("Transposed pattern for % by %".format(instrument, interval));
          };

        // Update pattern
        if(newPattern.notNil) {
          ~patternEngine.patternData[instrument.asSymbol] = newPattern;
          ~patternEngine.updatePattern.(instrument, newPattern);
        };
      };
    }

    // Unknown event type
    {
      ~stateManager.log.("Warning: Unknown event type: %".format(eventType), \warn);
    };

  true;
};

// Add a single event to the timeline
~timelineInterpreter.addEvent = { |event|
  // Add to timeline data
  ~timelineInterpreter.timelineData.add(event);

  // Resort timeline
  ~timelineInterpreter.timelineData = ~timelineInterpreter.timelineData.sort({ |a, b|
    a[\beat] < b[\beat]
  });

  // Register section marker if applicable
  if(event[\type] == \sectionMarker && event[\name].notNil) {
    ~timelineInterpreter.sectionMarkers[event[\name].asSymbol] = event[\beat];
  };

  // Add to event queue if timeline is active
  if(~timelineInterpreter.executeRoutine.notNil && ~timelineInterpreter.executeRoutine.isPlaying) {
    ~timelineInterpreter.eventQueue.put(event[\beat], event);
  };

  ~stateManager.log.("Added event to timeline: % at beat %".format(event[\type], event[\beat]));

  true;
};


"Timeline interpreter module loaded successfully.".postln;
~timelineInterpreter;
)