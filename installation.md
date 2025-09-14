---
layout: page
title: Installation
permalink: installation
---

## From AssetLib

You can install Gedis directly from the Godot Asset Library: [Gedis - Godot Redis Client](https://godotengine.org/asset-library/asset/4292)

Then, enable the plugin in **Project -> Project Settings -> Plugins**.

## Manual Installation

1.  Copy the entire `addons/Gedis` folder into your Godot project's `addons` directory.
2.  In Godot, go to **Project -> Project Settings -> Plugins** and enable the "Gedis" plugin.
3.  The plugin will register an autoloaded singleton named `Gedis`, which is now available globally in your scripts.