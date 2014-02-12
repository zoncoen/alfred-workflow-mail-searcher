# Mail Searcher

The Alfred workflow to search messages on Mail.app.

# Installation

1. Download [MailSearcher.alfredworkflow](https://raw.github.com/zoncoen/alfred-workflow-mail-searcher/master/Mail%20Searcher.alfredworkflow).
2. Double-click it to import into Alfred2.

(You need to buy the [Powerpack](https://buy.alfredapp.com/) to use workflows.)

# Updating

[Alleyoop](http://www.alfredforum.com/topic/1582-alleyoop-update-alfred-workflows/) is the Alfred workflow which makes updating workflows easier for users.
You can update this Alfred workflow easily if use Alleyoop.

### Alleyoop

1. Enter the keyword `oop` on Alfred2, Alleyoop checks for the update.
2. Download the latest version automatically if there is any update.
3. Double-click it to import into Alfred2.

You can also use [Monkey Patch](https://github.com/BenziAhamed/monkeypatch-alfred).

### Monkey Patch

1. Enter the keyword `mp update` on Alfred2, Monkey Patch checks for the update.
2. Download and import the latest version automatically if there is any update.

# Commands

### Search messages

```
mls {query}
```

You can use Gmail like advanced search operators in search.
The available operators are following:

|Operator|Definition|Examples|
|-----|-----|-----|
|from:|Used to specify the sender.|Example: from:amy<br>Meaning: Messages from Amy|
|to:|Used to specify a recipient.|Example: to:david<br>Meaning: All messages that were sent to David|
|subject:|Search for words in the subject line.|Example: subject:dinner<br>Meaning: Messages that have the word "dinner" in the subject|
|is:starred<br>is:unread<br>is:read|Search for messages that are starred, unread, or read.|Example: is:read is:starred from:David<br>Meaning: Messages from David that have been read and are marked with a star|

(From [Advanced search - Gmail Help](https://support.google.com/mail/answer/7190?hl=en).)

# Roadmap

- Add tests.
- Add other advanced search operators.
- More faster.

# Bugs

No bugs have been reported.
Please report any bugs or feature requests through the GitHub issues at <https://github.com/zoncoen/alfred-workflow-mail-searcher/issues>.

# Contributing

### Fork project

1. Fork this project.
2. Create your feature branch.
3. Commit your changes.
4. Push to the feature branch.
5. Create new Pull Request.

### Development Installation

This project use Carton which is Perl module dependency manager (aka Bundler for Perl).

```
$ cd src
$ carton install
```

# License

This software is released under the MIT License, see [LICENSE](https://raw.github.com/zoncoen/alfred-workflow-mail-searcher/master/LICENSE).
