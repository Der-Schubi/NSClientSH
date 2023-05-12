# NSClientSH
NSClientSH is a Bash script to get values such as blood sugar from a NightScout instance.

![Conky](https://github.com/Der-Schubi/NSClientSH/raw/main/conky.png)

NSClientSH requires jq for parsing json Data: https://stedolan.github.io/jq/
jq is directly available in most Linux distributions, e.g.: sudo apt-get install jq

The BG graph requires a Conky with integrated Lua support and the Cairo module for drawing.
If "Cairo" is listed below "Lua bindings" in the output of "conky -v", it will work.
Refer to the documentation of your Linux distributionn on how to install this module.
For Ubuntu install either the conky-cairo or the conky-all package.

