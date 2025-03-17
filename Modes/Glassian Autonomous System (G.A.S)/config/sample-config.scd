// sample-config.scd
// Configuration for sample paths and instrument settings
// Edit this file to match your system's sample locations

(
// Base sample path - modify this to match your system
~sampleConfig = (
  // Base path to sample directory
  basePath: "C:/Users/YourUsername/Music/Samples/Iowa Samples/",
  
  // Individual folder paths for each instrument/articulation
  folders: (
    piano: (
      ff: "Piano/Piano.ff/",
      mf: "Piano/Piano.mf/",
      pp: "Piano/Piano.pp/"
    ),
    
    marimba: (
      cord: "Marimba/Marimba.cord.ff.stereo/",
      rubber: "Marimba/Marimba.rubber.ff.stereo/",
      deadstroke: "Marimba/Marimba.deadstroke.ff.stereo/"
    ),
    
    flute: (
      vib: "Flute/Flute.vib.ff.stereo/",
      nonvib: "Flute/Flute.nonvib.ff.stereo/"
    )
  ),
  
  // Note name position in filename for each instrument
  notePosition: (
    piano: 2,     // Example: Piano.ff.C4.aiff (note is at position 2)
    marimba: 3,   // Example: Marimba.cord.ff.C4.aiff (note is at position 3)
    flute: 3      // Example: Flute.vib.ff.C4.aiff (note is at position 3)
  ),
  
  // Default articulation to use for each instrument
  defaultArticulation: (
    piano: \ff,
    marimba: \cord,
    flute: \vib
  )
);

// Function to get full path for a specific instrument/articulation
~getSamplePath = { |instrument, articulation|
  var basePath = ~sampleConfig.basePath;
  var folder = ~sampleConfig.folders[instrument][articulation];
  
  if(folder.isNil) {
    "Unknown instrument/articulation combination: %/%".format(instrument, articulation).error;
    ^nil;
  };
  
  basePath ++ folder;
};

// Function to get note position for an instrument
~getNotePosition = { |instrument|
  ~sampleConfig.notePosition[instrument] ? 3; // Default to position 3
};

// Function to get default articulation for an instrument
~getDefaultArticulation = { |instrument|
  ~sampleConfig.defaultArticulation[instrument];
};

"Sample configuration loaded.".postln;
~sampleConfig;
)