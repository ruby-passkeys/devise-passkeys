# Contributing

## Installation

After checking out the repo, run the following to install both Bundler and Appraisal dependencies:

```sh
bin/setup
```

To run the test suite for all Appraisal variants, run:

```sh
bundle exec appraisal rake test
```

## Writing Documentation

Documentation is written using [YARD](http://yardoc.org/).

You can start a YARD server to view the generated documentation (with automatic reloading) by running:

```sh
bin/yard
```

The documentation site will now be available at [http://localhost:8808](http://localhost:8808)

## Interactive Console

You can also run the following for an interactive prompt that will allow you to experiment:

```sh
bin/console
```

# Gem installation & cutting

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).
