const crypto = require('crypto');

function randomId(size = 24) {
  return crypto.randomBytes(size).toString('hex');
}

function hashValue(value, salt = crypto.randomBytes(16).toString('hex')) {
  const derivedKey = crypto.scryptSync(value, salt, 64).toString('hex');
  return `${salt}:${derivedKey}`;
}

function verifyHash(value, hashedValue) {
  const [salt, expectedHash] = hashedValue.split(':');
  if (!salt || !expectedHash) {
    return false;
  }

  const actualHash = crypto.scryptSync(value, salt, 64).toString('hex');
  return crypto.timingSafeEqual(Buffer.from(actualHash), Buffer.from(expectedHash));
}

module.exports = {
  randomId,
  hashValue,
  verifyHash,
};
