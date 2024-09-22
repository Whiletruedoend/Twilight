# Twilight

Также доступна RU версия => [README-RU.md](https://github.com/Whiletruedoend/Twilight/blob/master/README-RU.md)

### Table of Contents
* [Idea](#Idea)
* [Platform support](#Platform-support)
* [Installation](#Installation)
* [Setting up](#Setting-up)
  + [Comments](#Comments)
  + [Matrix](#matrix)
  + [fail2ban](#fail2ban)
  + [Themes](#Themes)
  + [Production](#Production)
* [Current features](#Current-features)
* [Bugs and some features](#Bugs-and-some-features)
* [Schemas and screenshots](#Schemas-and-screenshots)
* [Contact](#Contact)

 <img src="https://i.imgur.com/j6FCqsv.png"></img>


P.S. The list of recent changes can be found <a href="https://github.com/Whiletruedoend/Twilight/blob/master/update_log.md">here</a>

## Idea

Analyzing various blog sites and the platforms adjacent to them (where the repost goes), we can single out the main problem: Each platform, in fact, has nothing to do with other platforms or with the blog. It follows from this:
 
  1. Stupidity to post the same thing in different places;
  2. The need to exists in other platforms yourself;
 
  Therefore, it was customary to write something like an article aggregator. The idea is simple - you write a post - it scatters across different platforms.
 
 For a visual representation of the implementation, see [Schemes and screenshots](#Schemes-and-screenshots); 
  
## Platform support
 
  * Telegram:
    * Send to platforms: Yes
    * Editing, deleting: Yes
    * Send from platform to site: Yes
    * Comment support: Yes
    * Support for attachments: pictures, video, audio, files
   
  * Matrix:
    * Send to platforms: Yes
    * Editing, deleting: Yes
    * Send from platform: No
    * Support for attachments: pictures, video, audio, files 
 
## Installation

  There are 2 ways of installation:
  
  ### Manual
 
  * Install ruby (3.3.2):
    * For [rvm](https://rvm.io/):
    ```ssh
     rvm install ruby-3.3.2
    ```
    * For [rbenv](https://github.com/rbenv/rbenv):
    ```ssh
     rbenv install 3.3.2
    ```
  * Install yarn: [Windows](https://github.com/yarnpkg/yarn/releases/download/v1.22.19/yarn-1.22.19.msi) | [Linux](https://www.ubuntupit.com/how-to-install-and-configure-yarn-on-linux-distributions/);
  * Install redis: [Windows](https://github.com/tporadowski/redis/releases) | [Linux](https://redis.io/docs/getting-started/);
  * Install imagemagick [Windows](https://imagemagick.org/script/download.php#windows) | [Linux](https://imagemagick.org/script/download.php#linux)
  * (Optional) Install [PostgreSQL](https://www.enterprisedb.com/downloads/postgres-postgresql-downloads);
  * Install project: 
  
    ```ssh
     git clone https://github.com/Whiletruedoend/Twilight
     cd Twilight/
     yarn install --check-files
     bundle install
     rails db:migrate
    ```
     
  * Setting up: `config/credentials.yml`
  * Run server with command: `rails s`

  **Windows gem install fixes**:
  ```
gem install pg -- --with-pg-dir="C:\Program Files\PostgreSQL\15" (insert your path)
gem install wdm -- --with-cflags=-Wno-implicit-function-declaration
  ```

### Docker

  ```
  git clone https://github.com/Whiletruedoend/Twilight
  cd Twilight/
  yarn
  ```
  * (Optional) Configure .env for existing postgres database
  * Configure config/credentials.yml
  * Run:
  ```
    docker build -t twilight .
  ```
  * After a successful build, run:
  ```
    docker-compose up twilight
  ```
  * (If you need make migrations, use):
  ```
    docker-compose run --rm twilight bin/rails db:migrate
  ```

The site will now be available at: `http://localhost:3080`

## Setting up

[Production] Don't forget to set variable *secret_key_base* in credentials.yml:

### Comments

To support broadcasting comments from Telegram to a blog post, you need to:
1. Check the bot's privacy settings;
2. Add a bot to the chat with comments;
3. When adding a channel, check the 'Include comments' checkbox; 

After that, the translation of comments should work.

### Matrix

A quick guide to setting up the matrix.
 
 1. Access is through the access_token. Receiving it through the Element client: `Settings -> Help & About --> *at the bottom* Acess token`
 2. To get the room ID, create a room, then RMB on the room and `Settings --> Details --> and here 'Internal room ID'`
### fail2ban
To be able to block the IP addresses of those who are trying to bypass the RSS token, used [fail2ban](https://www.fail2ban.org/wiki/index.php/Main_Page). Instructions:
* Install fail2ban;
* Setting up `credentials.yml`: switch `enabled:` on `true`;
* Create filter: `vim /etc/fail2ban/filter.d/twilight.conf`
* Paste there:
    ```ssh                                                  
    [INCLUDES]
    before = common.conf
    
    [Definition]
    failregex = ^.* (\[.*\])* Failed bypass token from <HOST> at .*$
    ```
* Create jail: `vim /etc/fail2ban/jail.d/twilight.conf`
* Paste there:
    ```
    [twilight]
    enabled = true
    maxretry = 7
    findtime = 180
    action = iptables-allports[name=twilight, protocol=all]
    bantime = 3600
    filter = twilight
    port = http,https
    logpath = /home/user/Twilight/log/production.log
    ```
  (**Important!** Don't forget to change the *logpath* to your own. For more information about the parameters, see the link above);
* Restart service: `systemctl restart fail2ban`

(Banned IPs can be found with the command: `sudo fail2ban-client status twilight`)
### Themes
To create your own theme, you need to create a file in the format `app/assets/stylesheets/mytheme_theme.scss`, edit it, then restart the application;
### Production
For the production, do not forget to recompile the assets:

`RAILS_ENV=production bundle exec rake assets:precompile`

## Current features
  
  * EN/RU languages support;
  * Ability to create/change themes;
  * Channel management, verification of data when entering (only for administrators);
  * Search for notes by title on the home page;
  * Captcha for authorization/registration;
  * The system of invite codes (optional);
  * Support for separate options for each platform;
  * Access specifiers notes (for everyone, for users, for yourself);
  * Create Delete tags, the ability of the user to select the desired tags (the result is displayed in RSS);
  * Ability to add comments to the article;
  * View statistics of registered users (only for administrators); 
  * Twitter-style feed;

## Bugs and some features
Features:
* [ANY] If you delete a channel and then delete a post, then the post will not be deleted from the platforms (no tokens - no deletion, it seems logical);
* [TG] If a post in telegram had text and attachments, and when editing, remove all attachments, then the post will be completely deleted. This is a feature of the cart, I cannot turn the capture into text, I need to create a new post;
* [TG] If you send several attachments of different types and use a caption, the attachments will be grouped into groups, the first group will be of the same type as the first attachment, and the caption will be attached to it;
* [TG] If a post was created with <= 4096 characters and when the post is updated its length will exceed 4096 characters, then a new message will be created, which may be at a far distance from the first one (for example, if there were more posts, it will go after them). I cannot move the message up, so I advise you to use the onlylink option in such cases; 

Bugs:

* [TG] When editing attachments in comments (adding a new one and deleting an old one), the order gets lost and when you edit it again, the wrong picture is deleted;

If you decide to fix them, I'll gladly accept the Pull Request; 

## Schemas and screenshots
ER-diagram(Ver. 1.0.1):
<img src="https://i.imgur.com/RQQCRpa.jpeg"></img>
Main page (configurating):
 * Version 0 (standalone page):
<img src="https://i.imgur.com/cVz0Quv.png"></img>
 * Version 1 [default] (posts):
 <img src="https://i.imgur.com/j6FCqsv.png"></img>
 * Version 2: (feed):
 <img src="https://i.imgur.com/FJ7z6vF.png"></img>
Profile page:
<img src="https://i.imgur.com/XDwP5n0.png"></img>
Manage channels:
<img src="https://i.imgur.com/ojERlTd.png"></img>
Invite codes:
<img src="https://i.imgur.com/FvAlzzT.png"></img>
Statistics:
<img src="https://i.imgur.com/WxAdMuD.png"></img>
Article creation (Default theme):
<img src="https://i.imgur.com/3QStroz.png"></img>
Specific article:
<img src="https://i.imgur.com/9F0W2Nr.png"></img>

## Contact
If you have any ideas or your own developments, then you can always contact me at the following addresses: 

- [Matrix](https://matrix.to/#/@whiletruedoend:matrix.org)