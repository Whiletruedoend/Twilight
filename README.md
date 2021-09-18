# Twilight

### Table of Contents
* [Idea](#Idea)
* [Current features and plans](#Current-features-and-plans)
* [Platform support](#Platform-support)
* [Installation](#Installation)
* [Setting up](#Setting-up)
  + [Comments](#Comments)
  + [Matrix](#matrix)
  + [fail2ban](#fail2ban)
  + [Themes](#Themes)
  + [Production](#Production)
* [Bugs and some features](#Bugs-and-some-features)
* [Security question](#Security-question)
* [Schemas and screenshots](#Schemas-and-screenshots)
* [Contribution](#Contribution)
* [Contact](#Contact)

 <img src="https://i.imgur.com/3QStroz.png"></img>


P.S. The list of recent changes can be found <a href="https://github.com/Whiletruedoend/Twilight/blob/master/update_log.md">here</a>

## Idea

Recently I thought about the implementation of blogs in different platforms, and came to the following problems:
 
 * The first is that there is no single site where you can put content;
 * Second, the problem is that everyone is sitting in different places;
 
    from these two it follows:
 
 * Third - stupidity to post the same thing in different places;
 * Fourth - you need to sit in other platforms yourself;
 
 Therefore, it was decided to write something like an article aggregator. It's simple - you write an article - it is scattered across different platforms. See the diagram and pictures at the very end;
 
 The diagram shows that there are channels on the platforms that belong to the owner, access to an ordinary user is carried out using the rss token. Let me explain: each registered user receives his own token and uses it to receive news from RSS. This has two advantages:
 
 1) Personalization by tagging the content that the user wants to see;
 2) Author's restriction of access rights to some articles;
 
 Of course, if we are talking about posting articles on other open platforms, restricting rights does not make much sense, however, the author's goal was not to build a completely isolated environment with control of each output node, if only because it is practically impossible to implement.
 
 The schematic and table of models is located under the heading [Schemes and screenshots] (# Schemes-and-screenshots); 
 
## Current features and plans
  
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
  
  
  For future options, see the github board in the `projects` tab;
 
## Platform support
 
  * Telegram:
    * Send to platforms: Yes
    * Editing, deleting: Yes
    * Send from platform: No
    * Comment support: Yes
    * Support for attachments: pictures, video, audio, files
   
  * Matrix:
    * Send to platforms: Yes
    * Editing, deleting: Yes
    * Send from platform: No
    * Support for attachments: pictures, video, audio, files 
 
## Installation
 
  * Install ruby (2.7);
  * Clone & install project: 
  
    ```ssh
     git clone https://github.com/Whiletruedoend/Twilight
     cd Twilight/
     yarn install --check-files
     bundle install
     rails db:migrate
    ```
     
  * Setting up: `credentials.yml`
  * Run: `rails s`
  
The site will now be available at: `http://localhost:3080`

## Setting up

Some settings are done through the console (`rails c`), but most work anyway, provided the data is entered correctly;
  * After registration, we make ourselves an administrator (for publishing articles and everything):
      ```ssh
       User.last.update(is_admin: true)
      ```
### Comments

For comments to work in Telegram, you must:
1. Check the bot's privacy settings;
2. Add a bot to the chat with comments;
3. When adding a channel, check the 'Include comments' checkbox; 

**Further, comment parsing is NOT automatically started when rails is loaded yet. Therefore, to run you need::**

1. ~~In config/application.rb comment out the line: RunTelegramPoller.perform_later~~ (not yet needed)
2. Manually run poller with the command: `rake tg:start`

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
* Restart: `systemctl restart fail2ban`

(Banned IPs can be found with the command: `sudo fail2ban-client status twilight`)
### Themes
To create your own theme, you need to create a file in the format `app/assets/stylesheets/mytheme_theme.scss`, edit it, then restart the application;
### Production
For the production, do not forget to recompile the assets:

`RAILS_ENV=production bundle exec rake assets:precompile`

## Bugs and some features
Features:
* [TG] If there is a title, but there is no post text, then the title is not sent;
* [TG] When you delete a post from any channel, all comments are deleted, incl. and tied to other posts. This is due to the fact that comments are tied to the post, not to the platform, otherwise, when viewing the post, you would have to show different versions of the text (for each channel) with different comments. And it is understood that the post is one (the same), just on several channels;
* [TG] If a post in telegram had text and attachments, and when editing, remove all attachments, then the post will be completely deleted. This is a feature of the cart, I cannot turn the capture into text, I need to create a new nost;
* [TG] If you send several attachments of different types and use a caption, the attachments will be grouped into groups, the first group will be of the same type as the first attachment, and the caption will be attached to it;
* [TG] If a post was created with <= 4096 characters and when the post is updated its length will exceed 4096 characters, then a new message will be created, which may be at a far distance from the first one (for example, if there were more posts, it will go after them). I cannot move the message up, so I advise you to use the onlylink option in such cases; 
* [ANY] If you delete a channel and then delete a post, then the post will not be deleted from the platforms (no tokens - no deletion, it seems logical);

Bugs:

* [TG] When editing attachments in comments (adding a new one and deleting an old one), the order gets lost and when you edit it again, the wrong picture is deleted;
* [TG] [TEMP] When adding a channel, you must manually restart the poller, or even the rails application, otherwise it will not be able to find the bot and create a post;

I'm too lazy to fix them, whoever wants (it would be very cool), then I will gladly accept the Pull Request; 

## Security question

Now it turns out that if a user has several channels, then even having several authorization tokens, only one (the very first specified) is used to preload pictures.

But let's say this situation: the user has 2 channels (2 tones, respectively), and there is a second person who knows the first token, but does not know the second. Then, proceeding from the logic that all attachments are loaded into a temporary channel from the first token, he can simply intercept the information that was intended for the second token.

Only the information from the first token is identical to the information from the second token (after all, the content is uploaded to different channels the same!), So even by intercepting this information, a conditional attacker will receive the same result.

Therefore, this does not seem to carry a serious threat. But just in case, he warned that there were no questions. 
## Schemas and screenshots
General scheme:
<img src="https://i.imgur.com/ffeGQGF.png"></img>
Model scheme (v. 0.65):
<img src="https://i.imgur.com/91dyP9L.png"></img>
Main page:
<img src="https://i.imgur.com/cVz0Quv.png"></img>
Profile page:
<img src="https://i.imgur.com/XDwP5n0.png"></img>
Manage channels:
<img src="https://i.imgur.com/ojERlTd.png"></img>
Invite codes:
<img src="https://i.imgur.com/FvAlzzT.png"></img>
Statistics:
<img src="https://i.imgur.com/gc9MnqT.png"></img>
Article creation (Default theme):
<img src="https://i.imgur.com/3QStroz.png"></img>
List of articles:
<img src="https://i.imgur.com/364Ytof.png"></img>
Specific article:
<img src="https://i.imgur.com/9F0W2Nr.png"></img>
## Contribution

  1) Fork tis project;
  2) Make changes to the forked project;
  3) On the page of this repository, poke Pull Requests and make a Pull Request by selecting your fork in the right list; 
  
## Contact
If you have any ideas or your own developments, or just questions about the performance of the code, then you can always contact me at the following addresses: 

- [Matrix](https://matrix.to/#/@whiletruedoend:matrix.org)
- Jabber: whiletruedoend@gensokyo.tk