const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');

class PsaProvider {
  constructor() {
    const venvPython = path.resolve(__dirname, '../../.venv/bin/python3');
    this.pythonBin = process.env.PSA_BRIDGE_PYTHON || (fs.existsSync(venvPython) ? venvPython : 'python3');
    this.bridgeScript = path.resolve(__dirname, '../../psa_bridge/bridge.py');
    this.timeoutMs = Number(process.env.PSA_BRIDGE_TIMEOUT_MS || 180000);
  }

  async submitCredentials(credentials) {
    return this.callBridge('submit_credentials', credentials);
  }

  async connect(payload = {}) {
    return this.callBridge('connect', payload);
  }

  async requestOtp() {
    return this.callBridge('request_otp', {});
  }

  async confirmOtp(payload) {
    return this.callBridge('confirm_otp', payload || {});
  }

  async syncVehicles() {
    return this.callBridge('sync_vehicles', {});
  }

  async runAction(vin, action, payload) {
    return this.callBridge('run_action', {
      vin,
      action,
      payload: payload || {},
    });
  }

  callBridge(command, payload) {
    return new Promise((resolve, reject) => {
      const args = [this.bridgeScript, command, JSON.stringify(payload || {})];
      const child = spawn(this.pythonBin, args, {
        env: process.env,
      });

      let stdout = '';
      let stderr = '';
      let timedOut = false;

      const timer = setTimeout(() => {
        timedOut = true;
        child.kill('SIGKILL');
      }, this.timeoutMs);

      child.stdout.on('data', (chunk) => {
        stdout += chunk.toString();
      });

      child.stderr.on('data', (chunk) => {
        stderr += chunk.toString();
      });

      child.on('error', (error) => {
        clearTimeout(timer);
        reject(error);
      });

      child.on('close', (code) => {
        clearTimeout(timer);

        if (timedOut) {
          reject(new Error('PSA bridge timed out.'));
          return;
        }

        let response;
        try {
          response = stdout.trim() ? JSON.parse(stdout) : null;
        } catch (_error) {
          reject(
            new Error(
              `PSA bridge returned invalid JSON. stderr: ${stderr.trim() || 'none'}`,
            ),
          );
          return;
        }

        if (code !== 0) {
          const message = response?.error || stderr.trim() || 'PSA bridge failed.';
          reject(new Error(message));
          return;
        }

        if (response?.error) {
          reject(new Error(response.error));
          return;
        }

        resolve(response);
      });
    });
  }
}

module.exports = {
  PsaProvider,
};
