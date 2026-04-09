<div align="center">
  <img src="https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/car-side.svg" alt="App Icon" width="80" height="80">
  <br />
  <br />
  <h1>PSA Controller</h1>
  <p>
    <strong>A sleek, modern management hub for Groupe PSA connected vehicles.</strong>
    <br />
    Peugeot • Citroen • DS • Opel • Vauxhall
  </p>
</div>

---

## ⚡ Overview

**PSA Controller** is a self-hosted, lightweight dashboard and integration layer bridging the gap between your car and your smart home ecosystem. Through an elegant unified interface, you can monitor battery telemetry, pre-condition your interior, lock/unlock doors, and oversee your trips and charging cycles entirely securely within your local network.

Featuring a built-in **Model Context Protocol (MCP)** server, you can pair this seamlessly with AI agents—like Claude—allowing them to directly query and manage your vehicle on your behalf.

> **Credits:** Built by standing on the shoulders of giants. Massive thanks to the [`psa_car_controller`](https://github.com/flobz/psa_car_controller) project on GitHub for deciphering the Groupe PSA connected APIs. This Project is heavily based on his modules. 


## 🚀 Quickstart

Run via Docker Compose (recommended):

```bash
docker-compose up -d
```

Or for native local execution:

```bash
./scripts/start-dev.sh
```
