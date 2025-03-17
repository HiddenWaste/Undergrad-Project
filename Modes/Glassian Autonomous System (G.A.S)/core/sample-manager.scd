// sample-loader.scd
// Sample loading module for the Glass-inspired system
// This module handles loading multi-articulation instrument samples

(
// Create namespace for the sample loader
~sampleLoader = ();

// Initialize the sample loader
~sampleLoader.init = { |basePath|
  var sampleDict, instrumentDict;

  // Just store the path and print a message
  ~sampleLoader.basePath = basePath.asString;

  // Create empty dictionaries
  ~sampleLoader.samples = Dictionary.new;
  ~sampleLoader.instruments = Dictionary.new;

  // Add basic sample player SynthDef if not already defined
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

  // Add reverb SynthDef for effects if not already defined
  SynthDef(\simpleReverb, {
    |in=0, out=0, mix=0.3, room=0.5, damp=0.5|
    var dry, wet;

    dry = In.ar(in, 2);
    wet = FreeVerb.ar(dry, mix, room, damp);
    Out.ar(out, wet);
  }).add;

  "Sample Loader initialized with base path: %".format(basePath).postln;

  // Return the initialized sample loader for chaining
  ~sampleLoader;
};

// Load samples from a folder with proper note naming
~sampleLoader.loadSampleFolder = { |folderPath, instrument, articulation, notePosition=3|
  var folder = PathName(folderPath);
  var count = 0;

  // Create instrument/articulation dictionaries if needed
  if(~sampleLoader.samples[instrument].isNil) {
    ~sampleLoader.samples[instrument] = Dictionary.new;
  };

  if(~sampleLoader.samples[instrument][articulation].isNil) {
    ~sampleLoader.samples[instrument][articulation] = Dictionary.new;
  };

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

        // Only show first 10 loading messages to avoid console spam
        if(count < 10) {
          "Loading % % %".format(instrument, articulation, noteName).postln;
        };
        if(count == 10) { "... (more samples) ...".postln; };

        ~sampleLoader.samples[instrument][articulation][noteName.asSymbol] =
          Buffer.read(s, file.fullPath);

        count = count + 1;
      };
    };
  };

  "Loaded % % % samples".format(count, instrument, articulation).postln;
  count;
};

// Play a note with specified parameters
~sampleLoader.playNote = { |instrument, note, articulation=nil, amp=nil, pan=0, attack=nil, release=nil, out=0, callback=nil|
  var instrumentSettings, articulationToUse, noteSymbol, buffer, synth;
  var attackTime, releaseTime, ampValue, synthID;

  // Validate instrument
  instrumentSettings = ~sampleLoader.instruments[instrument];
  if(instrumentSettings.isNil) {
    "Instrument % not loaded".format(instrument).warn;
    ^nil;
  };

  // Use default articulation if none specified
  articulationToUse = articulation ? instrumentSettings.defaultArticulation;

  // Convert note to symbol
  noteSymbol = note.asSymbol;

  // Get the buffer
  buffer = ~sampleLoader.samples[instrument][articulationToUse][noteSymbol];
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

  // Execute callback if provided
  if(callback.notNil) {
    callback.value(synth);
  };

  // Return the synth for reference
  synth;
};

// Play a direct note (simplified version without tracking)
~sampleLoader.playNoteDirect = { |instrument, note, articulation=nil, amp=0.7, pan=0|
  var noteSymbol = note.asSymbol;
  var buffer, attackTime, releaseTime;

  // Get correct buffer based on instrument and articulation
  if(articulation.isNil && (~sampleLoader.instruments[instrument].notNil)) {
    articulation = ~sampleLoader.instruments[instrument].defaultArticulation;
  };

  buffer = ~sampleLoader.samples[instrument][articulation][noteSymbol];

  // Set parameters based on instrument
  case
    { instrument == \flute } {
      attackTime = 0.01;
      releaseTime = 0.3;
    }
    { instrument == \marimba } {
      attackTime = 0.005;
      releaseTime = 0.5;
    }
    { instrument == \piano } {
      attackTime = 0.001;
      releaseTime = 0.3;
      amp = amp * 1.5; // Piano often needs higher amplitude
    }
    {
      attackTime = 0.01;
      releaseTime = 0.3;
    };

  if(buffer.notNil) {
    "Playing % % %".format(instrument, articulation, noteSymbol).postln;

    Synth(\samplePlayer, [
      \buf, buffer,
      \amp, amp,
      \pan, pan,
      \attack, attackTime,
      \release, releaseTime
    ]);
  } {
    "Note % for % % not loaded".format(noteSymbol, instrument, articulation).warn;
  };
};

// Setup a reverb effect bus and synth
~sampleLoader.setupReverb = { |out=0, mix=0.3, room=0.5, damp=0.5|
  // Create a stereo bus for the reverb
  ~sampleLoader.reverbBus = Bus.audio(s, 2);

  // Create the reverb synth
  ~sampleLoader.reverbSynth = Synth(\simpleReverb, [
    \in, ~sampleLoader.reverbBus,
    \out, out,
    \mix, mix,
    \room, room,
    \damp, damp
  ], addAction: \addToTail);

  "Reverb setup complete on bus %".format(~sampleLoader.reverbBus).postln;

  // Return the reverb bus
  ~sampleLoader.reverbBus;
};

// Play a note with reverb
~sampleLoader.playNoteWithReverb = { |instrument, note, articulation=nil, dryAmp=0.7, wetAmp=0.3, pan=0|
  var directSynth;
  var reverbSend;

  // Check if reverb is set up
  if(~sampleLoader.reverbBus.isNil) {
    ~sampleLoader.setupReverb.();
  };

  // Play the direct sound
  directSynth = ~sampleLoader.playNoteDirect.(instrument, note, articulation, dryAmp, pan);

  // Send a copy to the reverb bus
  if(directSynth.notNil && ~sampleLoader.reverbBus.notNil) {
    reverbSend = Synth(\samplePlayer, [
      \buf, ~sampleLoader.samples[instrument][articulation][note.asSymbol],
      \amp, wetAmp,
      \pan, pan,
      \attack, 0.005,
      \release, 0.5,
      \out, ~sampleLoader.reverbBus
    ]);
  };

  // Return the direct synth
  directSynth;
};

// Free all samples for an instrument
~sampleLoader.freeInstrument = { |instrument|
  if(~sampleLoader.samples[instrument].notNil) {
    ~sampleLoader.samples[instrument].keysValuesDo { |articulation, sampleDict|
      sampleDict.keysValuesDo { |noteName, buffer|
        if(buffer.notNil) {
          buffer.free;
        };
      };
    };

    ~sampleLoader.samples[instrument] = Dictionary.new;
    ~sampleLoader.instruments.removeAt(instrument);

    "Freed all samples for instrument %".format(instrument).postln;
  } {
    "Instrument % not loaded".format(instrument).warn;
  };
};

// Free all loaded samples
~sampleLoader.freeAllSamples = {
  ~sampleLoader.samples.keysValuesDo { |instrument, articulationDict|
    articulationDict.keysValuesDo { |articulation, sampleDict|
      sampleDict.keysValuesDo { |noteName, buffer|
        if(buffer.notNil) {
          buffer.free;
        };
      };
    };
  };

  ~sampleLoader.samples = Dictionary.new;
  ~sampleLoader.instruments = Dictionary.new;

  "All samples freed.".postln;
};

// Print a summary of loaded samples
~sampleLoader.printSummary = {
  "=== Sample Loader Summary ===".postln;

  if(~sampleLoader.samples.isNil || (~sampleLoader.samples.size == 0)) {
    "No samples loaded.".postln;
    ^nil;
  };

  ~sampleLoader.samples.keysValuesDo { |instrument, articulationDict|
    "Instrument: %".format(instrument).postln;

    articulationDict.keysValuesDo { |articulation, sampleDict|
      "  %: % samples".format(articulation, sampleDict.size).postln;

      if(sampleDict.size > 0) {
        var noteList = sampleDict.keys.asArray.sort;
        var displayNotes = if(noteList.size <= 10) {
          noteList;
        } {
          noteList[0..9] ++ ["... (% more)".format(noteList.size - 10)];
        };

        "    Notes: %".format(displayNotes).postln;
      };
    };
  };

  "===========================".postln;
};

// Get a list of available notes for an instrument/articulation
~sampleLoader.getAvailableNotes = { |instrument, articulation=nil|
  var instrumentSettings, articulationToUse, sampleDict;

  // Validate instrument
  instrumentSettings = ~sampleLoader.instruments[instrument];
  if(instrumentSettings.isNil) {
    "Instrument % not loaded".format(instrument).warn;
    ^nil;
  };

  // Use default articulation if none specified
  articulationToUse = articulation ? instrumentSettings.defaultArticulation;

  // Get the sample dictionary
  sampleDict = ~sampleLoader.samples[instrument][articulationToUse];
  if(sampleDict.isNil || sampleDict.size == 0) {
    "No samples loaded for % %".format(instrument, articulationToUse).warn;
    ^nil;
  };

  // Return sorted array of available notes
  sampleDict.keys.asArray.sort;
};

"Sample Loader module loaded successfully.".postln;
~sampleLoader;
)