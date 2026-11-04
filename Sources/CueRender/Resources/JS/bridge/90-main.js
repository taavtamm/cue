// Wiring: pick the right player for this deck and route Swift's commands.

function choosePlayer(config) {
  if (config.renderMode === 'passthrough') return cue.createPassthroughPlayer(config);
  const isClaudeDesign = document.getElementById('deck-motion') && document.querySelector('.deck-scaler');
  if (isClaudeDesign) {
    try {
      return cue.createClaudeDesignPlayer(config);
    } catch (error) {
      cue.reportError(error); // A malformed deck-motion block: fall back to the generic player.
    }
  }
  return cue.createGenericPlayer(config);
}

let player = null;

cue.handlers.configure = ({ config }) => {
  cue.config = config; // Other parts read the slide selector and surface.
  player = choosePlayer(config);
  cue.post('ready', { slideCount: player.slideCount, player: player.name });
  const known = player.liveSlides ? player.liveSlides() : [];
  cue.post('liveContent', { slides: cue.findLiveSlides(player.slides, known) });
};

cue.handlers.show = ({ position, finished }) => {
  if (!player) return cue.reportError('show before configure');
  player.show(position, finished === true);
};

cue.handlers.setPaused = ({ value }) => cue.pause.set(value === true);

/** Pausing swaps live embeds for stills (62-freeze.js): stop them first. */
cue.onFreeze = () => {
  if (player && player.stopEmbeds) player.stopEmbeds();
};

/** After a pause, the stills are gone: start the live embeds again. */
cue.onThaw = () => {
  if (player && player.restartEmbeds) player.restartEmbeds();
};

/** For tests and the web inspector. Lives only in Cue's world. */
cue.debug = () => (player ? Object.assign({ player: player.name }, player.debug()) : null);
