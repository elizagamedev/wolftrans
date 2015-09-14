# Wolf Trans
## A translation tool for Wolf RPG Editor games
![](http://i.imgur.com/fzuJjsU.png)

## Summary
Wolf Trans is a set of tools to aid in the translation of games made using
[Wolf RPG Editor](http://www.silversecond.com/WolfRPGEditor/). The syntax and functionality is inspired primarily by the [RPG Maker Trans](http://rpgmakertrans.bitbucket.org/) project.

## Installation
Installation is as easy as typing this command in your terminal:

    gem install wolftrans

If you are using Windows, you will need to have Ruby installed first. You can download it from [here](http://rubyinstaller.org/downloads/).

## Example
The source code for the translation patch file used in the sample image above is the following:

    > BEGIN STRING
    ウルファール
    「ようこそ、\\r[WOLF,ウルフ] RPGエディターの世界へ！
    　私は案内人のウルファールと申します。
    > CONTEXT MPS:TitleMap/events/0/pages/1/65/Message
    Wolfarl
    "Welcome to the world of WOLF RPG Editor!
     I am Wolfarl, your guide."
    > END STRING

All of the translatable game text is first extracted by Wolf Trans into plaintext files, which can then be edited by a translator. Refer to RPG Maker Trans's documentation for now for a more thorough explanation, as the two share very similar designs.

## Usage

Currently, Wolf Trans can be invoked with the command line:

    wolftrans game_dir patch_dir out_dir

If `patch_dir` does not exist, it will be automatically generated with the text contained in the data files of the game in `game_dir`. `out_dir` will contain the patched game.

The behavior of the command line arguments will almost certainly be revised in a future version.

## Todo

* Code cleanup. Much of the code was written when reverse-engineering.
* Patching Game.exe to translate miscellaneous text embedded in the binary.
* etc.

## Disclaimer

This project is still in a very early state, and probably won't work with all games. Make sure to backup your translation work frequently in case of errors until this project is stable. I am not personally responsible for anything done by this tool.
