# Home Assistant Add-on: Omada

This add-on runs TP Links' Omada Controller software, which
allows you to manage your Omada network via the web browser. The add-on
provides a single-click installation and run solution for Home Assistant,
allowing users to get their network up, running, and updated, easily.

## Installation

The installation of this add-on is pretty straightforward and not different in
comparison to installing any other Home Assistant add-on.

1. Click the Home Assistant My button below to open the add-on on your Home
   Assistant instance.

   [![Open this add-on in your Home Assistant instance.][addon-badge]][addon]

1. Click the "Install" button to install the add-on.
1. Check the logs of the "Omada Application" to see if everything went
   well.
1. Click the "OPEN WEB UI" button, and follow the initial wizard.
1. After completing the wizard, log in with the credentials just created.
1. Go to the settings (gears icon in the bottom left) -> System ->
   Application Configuration.
1. Toggle `Override Inform Host`.
1. Change the `Host for Inform` to match the IP or hostname of
   the device running Home Assistant.
1. Hit the "Apply Changes" button to activate the settings.
1. Ready to go!

## Authors & contributors

The original setup of this repository is by [Tristan Bastian][reey].

It has been heavily inspired by [mbentley][https://github.com/mbentley/docker-omada-controller]
