const { PsaProvider } = require('./provider');

function getPsaProvider() {
  return new PsaProvider();
}

module.exports = {
  getPsaProvider,
};
