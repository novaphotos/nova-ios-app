Nova Camera for iOS
===================

This is the Nova camera application. See https://wantnova.com/ or http://kck.st/1dOtham

Requirements
------------

* Xcode 5
* Cocoapods (http://cocoapods.org) - follow the introductory guide on their site, or if you have rubygems available, run `sudo gem install cocoapods`

Initial setup
-------------

* Create a local config file

		cp NovaCamera/Config.sample.h NovaCamera/Config.h
	
	Optionally, edit this new file (`NovaCamera/Config.h`) and replace API keys and other credentials.
	
* Install third party libraries and dependencies via Cocoapods

		pod install
		
* Open the project by double-clicking the `NovaCamera.xcworkspace` file that Cocoapods has created. *Do not use the `NovaCamera.xcodeproj` file to open the project.*

	Alternately: `open NovaCamera.xcworkspace`
	
Build and run the project
-------------------------

Plug an iOS 7 device in via USB. If Xcode prompts you, specify that you would like to "Use this device for development."  The iPhone and iPad Simulator apps do not include camera support so they are useless for testing this app.

In the Xcode project window, you should see icons toward the top left indicating the selected _Scheme_ and _Destination_. These settings are also available via the _Product_ menu under _Scheme_ and _Destination_.  Select `NovaCamera` for the _Scheme_ and select the iOS device you plugged in for _Destination_.

![Xcode scheme and destination](http://pixor.net/temp/skitch/NovaCamera.xcworkspace_%E2%80%94_SSCaptureSessionManager.m-20140106-191948.png)

You should now be able to _Run_ your application using the "Play" icon on the top left of the Xcode project window, through the _Product_ menu under _Run_, or by pressing _Command-R_.

Generating the project documentation
------------------------------------

Documentation for the project can be generated through the [appledoc](http://gentlebytes.com/appledoc/) utility.  Follow the installation instructions for _appledoc_ or alternately, using Homebrew: `brew install appledoc`.  The documentation can then be generated via:

	make docs
	
This will invoke `appledoc` and generate the documentation. There will be errors for all undocumented methods and properties found in the project. An HTML version of the generated documentation will be available in the `docs/html/` directory; you can simply `open docs/html/index.html` to open in your default web browser.
