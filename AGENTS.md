# Velocity Repository Agent Guide

This document provides a comprehensive overview of the Velocity repository to help AI agents understand its structure, purpose, and functionality.

## Overview

Velocity is a collection of tools designed to reduce boilerplate and repetitive work in larger Xcode projects, especially in multi-developer environments. It's part of an opinionated toolchain for project management that uses:

- Xcodegen for generating Xcode project files
- Swift Package Manager (SPM) for external dependencies
- Velocity's own package system for internal modules
- The Inject library for dependency injection

## Core Purpose

The main benefits of using Velocity include:
1. Faster Xcode dependency resolution by caching external SwiftPM dependencies locally
2. Automatic generation of xcodegen .yml files for all internal modules and external dependencies
3. Proper module structure with API/implementation best practices
4. Lightweight module creation that encourages proper modularization

## Repository Structure

### Root Directory Files
- `README.md` - Main project documentation
- `Package.swift` - Swift package manifest
- `Makefile` - Build automation commands
- `Mintfile` - Dependency management configuration
- `AGENTS.md` - This file

### Source Code Structure
- `Sources/Command/` - Main command-line interface implementations
- `Sources/Libraries/` - Core libraries used by the commands:
  - `DependencyMagnet/` - Handles external dependency management
  - `ModuleGeneration/` - Module generation utilities
  - `ModuleManagement/` - Module management logic
  - `InternalUtilities/` - Shared utility functions

### Demo Application Structure
- `Demo/` - Example application demonstrating Velocity usage
  - `Modules/` - Internal modules following Velocity patterns
  - `project.yml` - XcodeGen project configuration
  - `dependencies.yml` - External dependencies configuration

## Main Commands

### `pull-dependencies`
- Fetches external SwiftPM-based dependencies and stores them in a local silo
- Allows Xcode to treat them as local packages, avoiding remote version resolution
- Uses `dependencies.yml` configuration file

### `generate-imports`
- Generates imports.yml files for modules
- Automatically discovers and creates import dependencies

### `generate-inject`
- Generates Inject extension files for dependency injection
- Creates registration functions for injections and builders

### `generate-package`
- Generates Package.swift files for modules
- Creates proper Swift package manifests

### `generate-resources`
- Handles resource generation for modules

### `generate-xcodegen-modules`
- Generates xcodegen configuration files for internal modules

### `generate-xcodegen-deps`
- Generates xcodegen configuration files for external dependencies

### `sanitize-xcodegen-project`
- Cleans up and sanitizes xcodegen project files

## Module Structure

Modules in Velocity follow a specific pattern:
```
MyNewCode/
  package.yml
  MyNewCode/        
  MyNewCodeImpl/
  MyNewCodeTests/
  MyNewCodeMocks/
```

Each module contains:
- A main module (named after the package)
- An implementation module (Impl)
- Tests and mocks directories
- An imports.yml file listing dependencies

## Key Libraries

### DependencyMagnet
Handles external dependency management by:
- Resolving package graphs locally
- Caching dependencies in a local directory
- Relinking Package.swift files to reference local versions

### ModuleManagementLib
Manages module creation, detection, and configuration.

### ModuleGenerationLib
Provides utilities for generating various module-related files (imports, inject, package, etc.)

## Usage Pattern

1. Define external dependencies in `dependencies.yml`
2. Create internal modules following the Velocity module pattern
3. Use Velocity commands to generate necessary files:
   - `velocity pull-dependencies` - Fetch external dependencies
   - `velocity generate-imports` - Generate import files
   - `velocity generate-inject` - Generate injection files
   - `velocity generate-xcodegen-modules` - Generate module xcodegen configs
   - `velocity generate-xcodegen-deps` - Generate dependency xcodegen configs
4. Use XcodeGen to generate the actual Xcode project files

## Development Workflow

1. Run `make setup` or equivalent to install dependencies
2. Make changes to modules or configuration files
3. Run appropriate Velocity commands to regenerate necessary files
4. Use XcodeGen to generate the project file
5. Open and build in Xcode

## Configuration Files

- `dependencies.yml` - External SwiftPM dependencies configuration
- `project.yml` - XcodeGen project configuration
- `package.yml` - Module package configuration
- `imports.yml` - Module import dependencies
