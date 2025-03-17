(
// data-analyst.scd
// Audio analysis and OSC communication for the Glass-inspired system
// Handles real-time audio analysis and external communication

/*
  Usage:
  1. Initialize using ~dataAnalyst.init()
  2. Start analysis using ~dataAnalyst.startAnalysis()
  3. Configure OSC using ~dataAnalyst.configureOSC()
  4. Send OSC messages using ~dataAnalyst.sendOSC()
*/

// Create namespace for the data analyst
~dataAnalyst = ();

// Initialize the data analyst
~dataAnalyst.init = { |analysisRate=10|
  // Make sure dependencies are available
  if(~stateManager.isNil) {
    "Error: State Manager must be initialized before Data Analyst".error;
    ^false;
  };

  // Initialize analysis parameters
  ~dataAnalyst.analysisRate = analysisRate;  // Times per second
  ~dataAnalyst.activeAnalysis = false;
  ~dataAnalyst.analysisRoutines = List.new;
  ~dataAnalyst.analysisData = ();

  // Initialize OSC
  ~dataAnalyst.oscEnabled = false;
  ~dataAnalyst.oscTargets = List.new;

  ~stateManager.log.("Data Analyst initialized with analysis rate: % Hz".format(analysisRate));

  // Return for chaining
  ~dataAnalyst;
};

// Create audio analysis buses and synths
~dataAnalyst.setupAnalysis = {
  // Create analysis buses
  ~dataAnalyst.analysisBusses = (
    amplitude: Bus.control(s, 1),
    centroid: Bus.control(s, 1),
    flatness: Bus.control(s, 1),
    zeroCrossings: Bus.control(s, 1)
  );

  // Create analysis synth
  ~dataAnalyst.analysisSynth = SynthDef(\audioAnalyzer, {
    arg in=0, ampBus, centroidBus, flatnessBus, zeroCrossingBus;
    var input = In.ar(in, 2).sum;
    var amp = Amplitude.kr(input);
    var centroid = SpecCentroid.kr(FFT(LocalBuf(2048), input));
    var flatness = SpecFlatness.kr(FFT(LocalBuf(2048), input));
    var zeroCrossing = ZeroCrossing.ar(input);

    Out.kr(ampBus, amp);
    Out.kr(centroidBus, centroid);
    Out.kr(flatnessBus, flatness);
    Out.kr(zeroCrossingBus, zeroCrossing);
  }).play(s, [
    \in, 0,  // Use main output
    \ampBus, ~dataAnalyst.analysisBusses.amplitude,
    \centroidBus, ~dataAnalyst.analysisBusses.centroid,
    \flatnessBus, ~dataAnalyst.analysisBusses.flatness,
    \zeroCrossingBus, ~dataAnalyst.analysisBusses.zeroCrossings
  ]);

  ~stateManager.log.("Audio analysis setup complete");

  ~dataAnalyst.analysisSynth;
};

// Start continuous analysis
~dataAnalyst.startAnalysis = {
  var analysisRoutine;

  // Setup analysis infrastructure if needed
  if(~dataAnalyst.analysisSynth.isNil) {
    ~dataAnalyst.setupAnalysis.();
  };

  // Start the analysis routine
  analysisRoutine = Routine({
    var updateInterval = 1 / ~dataAnalyst.analysisRate;

    ~dataAnalyst.activeAnalysis = true;

    inf.do({
      // Get values from buses
      ~dataAnalyst.analysisBusses.amplitude.get({ |val|
        ~dataAnalyst.analysisData.amplitude = val;
      });

      ~dataAnalyst.analysisBusses.centroid.get({ |val|
        ~dataAnalyst.analysisData.centroid = val;
      });

      ~dataAnalyst.analysisBusses.flatness.get({ |val|
        ~dataAnalyst.analysisData.flatness = val;
      });

      ~dataAnalyst.analysisBusses.zeroCrossings.get({ |val|
        ~dataAnalyst.analysisData.zeroCrossings = val;
      });

      // Calculate additional metrics
      ~dataAnalyst.updateDerivedMetrics.();

      // Send OSC if enabled
      if(~dataAnalyst.oscEnabled) {
        ~dataAnalyst.sendAnalysisOSC.();
      };

      updateInterval.wait;
    });
  });

  // Start the routine
  analysisRoutine.play;

  // Add to analysis routines for cleanup
  ~dataAnalyst.analysisRoutines.add(analysisRoutine);

  ~stateManager.log.("Started continuous audio analysis at % Hz".format(~dataAnalyst.analysisRate));

  analysisRoutine;
};

// Stop analysis
~dataAnalyst.stopAnalysis = {
  // Stop analysis routines
  ~dataAnalyst.analysisRoutines.do { |routine|
    if(routine.isPlaying) {
      routine.stop;
    };
  };

  ~dataAnalyst.analysisRoutines = List.new;
  ~dataAnalyst.activeAnalysis = false;

  // Free synth if exists
  if(~dataAnalyst.analysisSynth.notNil && ~dataAnalyst.analysisSynth.isPlaying) {
    ~dataAnalyst.analysisSynth.free;
    ~dataAnalyst.analysisSynth = nil;
  };

  // Free buses
  if(~dataAnalyst.analysisBusses.notNil) {
    ~dataAnalyst.analysisBusses.do { |bus|
      bus.free;
    };
    ~dataAnalyst.analysisBusses = nil;
  };

  ~stateManager.log.("Stopped audio analysis");

  true;
};

// Calculate derived metrics from raw analysis data
~dataAnalyst.updateDerivedMetrics = {
  var ampSmoothed = ~dataAnalyst.analysisData.amplitude ? 0;
  var centroidNorm = (~dataAnalyst.analysisData.centroid ? 0) / 10000;

  // Calculate dynamic level
  ~dataAnalyst.analysisData.dynamicLevel = ampSmoothed.linlin(0, 0.5, 0, 100);

  // Calculate brightness
  ~dataAnalyst.analysisData.brightness = centroidNorm.linlin(0, 1, 0, 100);

  // Calculate activity level
  ~dataAnalyst.analysisData.activity = (
    (~dataAnalyst.analysisData.dynamicLevel * 0.5) +
    (~dataAnalyst.analysisData.brightness * 0.3) +
    ((~dataAnalyst.analysisData.zeroCrossings ? 0) * 0.2)
  ).clip(0, 100);

  // Add to state for internal use
  ~stateManager.state.runtime.analysisData = ~dataAnalyst.analysisData;
};

// Configure OSC communication
~dataAnalyst.configureOSC = { |enabled=true, targets|
  ~dataAnalyst.oscEnabled = enabled;

  if(enabled) {
    // Add targets if provided
    if(targets.notNil) {
      targets.do { |target|
        ~dataAnalyst.addOSCTarget.(target.address, target.port);
      };
    };

    ~stateManager.log.("OSC communication enabled with % targets".format(~dataAnalyst.oscTargets.size));
  } {
    ~stateManager.log.("OSC communication disabled");
  };

  ~dataAnalyst.oscEnabled;
};

// Add an OSC target
~dataAnalyst.addOSCTarget = { |address, port|
  var newTarget = NetAddr(address, port);
  ~dataAnalyst.oscTargets.add(newTarget);

  ~stateManager.log.("Added OSC target: %:%".format(address, port));

  ~dataAnalyst.oscTargets.size;
};

// Send analysis data via OSC
~dataAnalyst.sendAnalysisOSC = {
  if(~dataAnalyst.oscEnabled.not || ~dataAnalyst.oscTargets.size == 0) {
    ^false;
  };

  ~dataAnalyst.oscTargets.do { |target|
    // Send main analysis data
    target.sendMsg(
      '/glassSystem/analysis',
      ~dataAnalyst.analysisData.amplitude ? 0,
      ~dataAnalyst.analysisData.centroid ? 0,
      ~dataAnalyst.analysisData.flatness ? 0,
      ~dataAnalyst.analysisData.dynamicLevel ? 0,
      ~dataAnalyst.analysisData.brightness ? 0,
      ~dataAnalyst.analysisData.activity ? 0
    );

    // Send musical state data
    target.sendMsg(
      '/glassSystem/musical',
      ~stateManager.getParam.("musical.tension") ? 0,
      ~stateManager.getParam.("musical.root") ? 60,
      ~stateManager.getParam.("musical.scale") ? "naturalMinor",
      ~stateManager.getParam.("runtime.currentBeat") ? 0
    );
  };

  true;
};

// Send a custom OSC message
~dataAnalyst.sendOSCMessage = { |address, args|
  if(~dataAnalyst.oscEnabled.not || ~dataAnalyst.oscTargets.size == 0) {
    ^false;
  };

  ~dataAnalyst.oscTargets.do { |target|
    target.sendMsg(address, *args);
  };

  true;
};

// Setup OSC receiver for incoming messages
~dataAnalyst.setupOSCReceiver = { |port=57120|
  var receiver;

  // Create OSC responders for incoming messages
  OSCdef(\glassSystemCmd, { |msg, time, addr, recvPort|
    var command = msg[1].asSymbol;

    ~stateManager.log.("Received OSC command: % from %".format(command, addr));

    // Process the command
    case
      // Start/stop commands
      { command == \start } {
        ~stateManager.start.();
      }
      { command == \stop } {
        ~stateManager.stop.();
      }

      // Process commands
      { command == \additive } {
        ~stateManager.updateParam.("process.currentProcess", \additive);
      }
      { command == \subtractive } {
        ~stateManager.updateParam.("process.currentProcess", \subtractive);
      }

      // Scale commands
      { command == \changeScale } {
        if(msg.size > 2) {
          ~musicalConstraints.changeScale.(msg[2].asSymbol);
        } {
          ~musicalConstraints.changeScale.();
        };
      }

      // Root commands
      { command == \changeRoot } {
        if(msg.size > 2) {
          ~musicalConstraints.changeRoot.(msg[2].asInteger);
        } {
          ~musicalConstraints.changeRoot.();
        };
      }

      // Instrument commands
      { command == \startInstrument } {
        if(msg.size > 2) {
          ~patternEngine.startPattern.(msg[2].asSymbol);
        };
      }
      { command == \stopInstrument } {
        if(msg.size > 2) {
          ~patternEngine.stopPattern.(msg[2].asSymbol);
        };
      }

      // Tempo commands
      { command == \setTempo } {
        if(msg.size > 2) {
          ~stateManager.updateParam.("timing.tempo", msg[2].asInteger);
        };
      }

      // Pattern transform commands
      { command == \transformPattern } {
        if(msg.size > 3) {
          var instrument = msg[2].asSymbol;
          var transform = msg[3].asSymbol;
          var event = (
            type: \patternTransform,
            instrument: instrument,
            transform: transform
          );

          if(msg.size > 4 && transform == \transpose) {
            event.interval = msg[4].asInteger;
          };

          ~timelineInterpreter.executeEvent.(event);
        };
      };

  }, '/glassSystem/command', recvPort: port);

  ~stateManager.log.("OSC receiver setup on port %".format(port));

  true;
};

// Create a timeline event when analysis detects significant changes
~dataAnalyst.setupAnalysisResponseEvents = { |threshold=15, cooldown=32|
  var lastEventBeat = 0;
  var analysisRoutine;

  // Start analysis if not already running
  if(~dataAnalyst.activeAnalysis.not) {
    ~dataAnalyst.startAnalysis.();
  };

  // Create response routine
  analysisRoutine = Routine({
    inf.do({
      var currentBeat = ~stateManager.getParam.("runtime.currentBeat") ? 0;
      var activity = ~dataAnalyst.analysisData.activity ? 0;
      var tension = ~stateManager.getParam.("musical.tension") ? 0;
      var eventType, event;

      // Check for significant activity and tension changes
      if(activity > threshold && tension > 50 && (currentBeat - lastEventBeat) >= cooldown) {
        eventType = [\patternTransform, \scaleChange, \rootChange].wchoose([0.5, 0.3, 0.2]);

        case
          { eventType == \patternTransform } {
            var instruments = ~stateManager.getParam.("patterns.instruments");
            var instrument = instruments.choose;
            var transform = [\invert, \retrograde, \transpose].choose;

            event = (
              type: \patternTransform,
              instrument: instrument,
              transform: transform
            );

            if(transform == \transpose) {
              event.interval = [-7, -5, -3, 3, 5, 7].choose;
            };
          }
          { eventType == \scaleChange } {
            event = (
              type: \scaleChange,
              scale: ~stateManager.getParam.("scales").keys.asArray.choose
            );
          }
          { eventType == \rootChange } {
            event = (
              type: \rootChange,
              interval: [-5, -3, 3, 4, 5, 7].choose
            );
          };

        // Execute the event
        ~timelineInterpreter.executeEvent.(event);

        // Update last event beat
        lastEventBeat = currentBeat;

        ~stateManager.log.("Analysis triggered event: % (activity: %, tension: %)".format(
          eventType,
          activity.round(0.1),
          tension.round(0.1)
        ));
      };

      1.wait;  // Check once per beat
    });
  });

  // Start the routine
  analysisRoutine.play(~stateManager.clock);

  // Add to routines for cleanup
  ~dataAnalyst.analysisRoutines.add(analysisRoutine);

  ~stateManager.log.("Analysis response events setup with threshold: %, cooldown: % beats".format(
    threshold, cooldown
  ));

  analysisRoutine;
};

"Data Analyst module loaded successfully.".postln;
~dataAnalyst;
)