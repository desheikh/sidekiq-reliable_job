# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2024-12-15

### Added

- Initial release
- Transactional outbox pattern for reliable job enqueuing
- Client middleware for automatic outbox creation
- Server middleware for job completion tracking
- Support for Sidekiq 7+ and Rails 7.1+
- Configurable outbox model and table name
- Advisory lock-based outbox processor
- Support for ActiveJob and native Sidekiq jobs
