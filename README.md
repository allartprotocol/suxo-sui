# SUI Suxo Project Setup Guide

This guide outlines the steps to set up the SUI Suxo project and preparing the project environment.

## Prerequisites

Before starting, ensure the following are installed on your system:
- Git
- Rust and Cargo (latest stable version)

## Installing SUI CLI

To install SUI CLI please refear [SUI documentation](https://docs.sui.io/guides/developer/getting-started/sui-install)

## Setting Up the SUI Suxo Project

After installing the SUI CLI, set up the SUI Suxo project by following these steps:

1. **Clone the SUI Suxo project repository:**
   ```sh
   git clone https://github.com/allartprotocol/suxo-sui.git
   ```
2. **Ensure the project's dependencies are correctly specified in the `Move.toml` file.** The provided `Move.toml` snippet indicates a dependency on the SUI framework:
   ```toml
   [dependencies]
   Sui = { git = "https://github.com/MystenLabs/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "framework/devnet" }
   ```
3. **Compile the project using the SUI CLI:**
   ```sh
   sui move build
   ```
4. **To run tests, use the following command:**
   ```sh
   sui move test
   ```
5. **For deploying or publishing modules to the SUI network, refer to the [SUI CLI documentation](https://docs.sui.io/guides/developer/first-app/publish) for specific commands and options.**


## Additional Information

- The `.gitignore` file is configured to ignore the `/build/` directory. Ensure any build artifacts are placed within this directory to keep them out of version control.
- For detailed documentation on the SUI CLI and its commands, visit the [SUI Documentation](https://docs.sui.io).

This guide aims to assist you in getting started with the SUI Suxo project. For further help, consider reaching out to the SUI developer community or reviewing the SUI documentation.

