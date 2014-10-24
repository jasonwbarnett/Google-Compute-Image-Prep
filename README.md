Google Compute Image Prep
=========================
I created this repo mainly to have something to reference when submitting tickets to Google
when things did not work as expected. I've never actually been able to build a custom
image that worked on Google Compute Engine.

If anyone ever gets this working, please let me know.

## Dependencies

1. The script assumes you're using a linux user `bootstrap`. On [lines 228-239][1] we create a task to remove the user on boot.

## Contributing

1. Fork it ( https://github.com/jasonwbarnett/Google-Compute-Image-Prep/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request


[1]: https://github.com/jasonwbarnett/Google-Compute-Image-Prep/blob/master/prep.sh#L228-L239
