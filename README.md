# stumpy_jpeg

WORK IN PROGRESS

Read sequential and progressive JPEGs.

* Does not support arithmetic encoding.

## Installation

1. Add the dependency to your `shard.yml`:
```yaml
dependencies:
  stumpy_jpeg:
    github: reiswindy/stumpy_jpeg
```
2. Run `shards install`

## Interface

* `StumpyJPEG.read(file : String) : Canvas` reads a JPEG image from a file
* `StumpyJPEG.read(io : IO) : Canvas` reads a JPEG image from an IO
* `StumpyJPEG::JPEG` holds image associated data during parsing

## Usage

```crystal
require "stumpy_jpeg"

canvas = StumpyJPEG.read("yamboli.jpg")
```

For progressive reading

```crystal
require "stumpy_jpeg"

StumpyJPEG.read("yamboli.jpg") do |canvas|
  r, g, b = canvas[0, 0].to_rgb8
  puts "red=#{r}, green=#{g}, blue=#{b}"
end
```

## To Do / Wishlist

- [ ] JFIF header parsing support
- [x] Downsampled image support
- [ ] Arithmetic encoding support
- [ ] Add more tests

## Contributing

1. Fork it (<https://github.com/reiswindy/stumpy_jpeg/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [reiswindy](https://github.com/reiswindy) - creator and maintainer
