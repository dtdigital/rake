# Overview

A collection of scripts for automating some repetive tasks broken into the following (as at time of writing) categories:

* Projects
* Email
* Images
* Files

Check the rake task description for more information

	rake -T
	

# Installation

The scripts need to be installed in your $HOME directory under .rake (for mac / linux). Not sure about Windows, but I'm certain it's probably something complicated and stupid so try googling it.

A few of the scripts require gem dependecies and ruby 1.9+, so it's recommended to install RVM if you don't want to pollute your global gems: <http://beginrescueend.com/rvm/install/>

The gemfile requires the awesome bundler:
<http://gembundler.com/>

	 gem install bundler
	 

Once this is done, just install the deps
	
	bundle install
	
## Passwords, API Keys and Secrets

For obvious reasons, all passwords, API keys and secrets are stored in environment variables.

You will need to check with a team member as to details but below is a list of ENV vars used in the scripts.

	export AWS_ACCESS_KEY_ID=""
	export AWS_SECRET_ACCESS_KEY=""
	export BETSY_CAMPFIRE_API=""





