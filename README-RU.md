# Twilight

Also available EN version => [README.md](https://github.com/Whiletruedoend/Twilight/blob/master/README.md)

### Table of Contents
* [Идея](#Идея)
* [Поддержка платформ](#Поддержка-платформ)
* [Установка](#Установка)
* [Настройка](#Настройка)
  + [Комментарии](#Комментарии)
  + [Matrix](#matrix)
  + [fail2ban](#fail2ban)
  + [Темы](#Темы)
  + [Продакшн](#Продакшн)
* [Текущие возможности](#Текущие-возможности)
* [Баги и некоторые особенности](#Баги-и-некоторые-особенности)
* [Схемы и скриншоты](#Схемы-и-скриншоты)
* [Связь](#Связь)

 <img src="https://i.imgur.com/j6FCqsv.png"></img>


P.S. Список последних изменений можно посмотреть <a href="https://github.com/Whiletruedoend/Twilight/blob/master/update_log.md">тут</a>

## Идея

Анализируя различные сайты-блоги и прилегающие к ним платформы (куда идёт репост), можно выделить главную проблему: Каждая платформа по сути никак не связана ни с другими платформами, ни с блогом. Из этого вытекает:
 
 1. Глупость самому постить одно и то же в разные места;
 2. Необходимость самому сидеть в других платформах;
 
 Поэтому было принято написать что-то вроде агрегатора статей. Идея простая - пишешь пост - он разлетается по разным платформам.
 
 Визуальное представление реализации см. в [Схемы и скриншоты](#Схемы-и-скриншоты);
 
## Поддержка платформ
 
 * Telegram: 
   * Отправка в платформы: Да
   * Редактирование, удаление: Да
   * Отправка из платформы на сайт: Да
   * Поддержка комментариев: Да
   * Поддержка аттачменов: картинки, видео, аудио, файлы
   
 * Matrix: 
   * Отправка в платформы: Да
   * Редактирование, удаление: Да
   * Отправка из платформы: Нет
   * Поддержка аттачменов: картинки, видео, аудио, файлы
 
## Установка

  Есть 2 способа установки:

  ### Обычный
 
  * Установить ruby (3.3.2):
    * Для [rvm](https://rvm.io/):
    ```ssh
     rvm install ruby-3.3.2
    ```
    * Для [rbenv](https://github.com/rbenv/rbenv):
    ```ssh
     rbenv install 3.3.2
    ```
  * Установить yarn: [Windows](https://github.com/yarnpkg/yarn/releases/download/v1.22.19/yarn-1.22.19.msi) | [Linux](https://www.ubuntupit.com/how-to-install-and-configure-yarn-on-linux-distributions/);
  * Установить redis: [Windows](https://github.com/tporadowski/redis/releases) | [Linux](https://redis.io/docs/getting-started/);
  * Установить imagemagick [Windows](https://imagemagick.org/script/download.php#windows) | [Linux](https://imagemagick.org/script/download.php#linux)
  * (Не обязательно) Установить [PostgreSQL](https://www.enterprisedb.com/downloads/postgres-postgresql-downloads);
  * Загрузить проект: 
  
    ```ssh
     git clone https://github.com/Whiletruedoend/Twilight
     cd Twilight/
     yarn install --check-files
     bundle install
     NODE_OPTIONS=--openssl-legacy-provider bundle exec rake webpacker:compile
     NODE_OPTIONS=--openssl-legacy-provider bundle exec rake assets:precompile
     rails db:migrate
    ```
     
  * Настроить: `config/credentials.yml`
  * Запустить сервер командой: `rails s`

  **Windows установка проблемных гемов**:
  ```
gem install pg -- --with-pg-dir="C:\Program Files\PostgreSQL\15" (вставьте ваш путь)
gem install wdm -- --with-cflags=-Wno-implicit-function-declaration
  ```

  ### Docker

  ```
  git clone https://github.com/Whiletruedoend/Twilight
  cd Twilight/
  yarn
  ```
  * (Не обязательно) Настроить файл .env для подключения к существующей бд postgres
  * Настроить config/credentials.yml
  * Выполнить команду:
  ```
    docker build -t twilight .
  ```
  * После успешной сборки образа, выполнить:
  ```
    docker-compose up twilight
  ```
  * (Если нужно выполнить миграции, то):
  ```
    docker-compose run --rm twilight bin/rails db:migrate
  ```

Теперь сайт будет доступен по адресу: `http://localhost:3080`

## Настройка

[Production] Не забудьте настроить переменную secret_key_base в файле credentials.tml!

### Комментарии
Для поддержки трансляции комментариев из Telegram в пост блога, необходимо:
1. Проверить настройки приватности бота;
2. Добавить бота в чат с комментариями;
3. При добавлении канала поставить галку 'Включить комментарии';

После чего трансляция комментариев должна заработать.

### Matrix
 Краткая инструкция по настройке matrix.
 
 1. Доступ осуществляется через access_token. Его получение через клиент Element: `Все настройки -> Помощь & О программе --> *в самом низу* Токен доступа`
 2. Для получения ID комнаты, создаём комнату, после чего ПКМ на комнате и `Настройки --> Подробности --> и тут 'Внутренний ID комнаты'`
### fail2ban
Для возможности блокировки IP адресов тех, кто пытается сбрутофорсить RSS токен, используется [fail2ban](https://www.dmosk.ru/instruktions.php?object=fail2ban). Инструкция:
* Установить пакет fail2ban;
* Настроить `credentials.yml`: выставить `enabled:` на `true`;
* Создать фильтр: `vim /etc/fail2ban/filter.d/twilight.conf`
* Вставить туда код ниже:
    ```ssh                                                  
    [INCLUDES]
    before = common.conf
    
    [Definition]
    failregex = ^.* (\[.*\])* Failed bypass token from <HOST> at .*$
    ```
* Создать jail: `vim /etc/fail2ban/jail.d/twilight.conf`
* Вставить туда код ниже:
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
  (**Важно!** Не забудьте поменять путь *logpath* на свой. Подробнее про параметры см.выше по ссылке);
* Перезапустить сервис: `systemctl restart fail2ban`

(Забаненные IP можно узнать командой:`sudo fail2ban-client status twilight`)
### Темы
Для создания своей темы необходимо создать файл в формате `app/assets/stylesheets/название_theme.scss`, отредактировать его, затем перезапустить приложение;

## Текущие возможности
  
  * Поддержка EN/RU языков;
  * Возможность создавать/менять темы;
  * Управление каналами, проверка данных при вводе (только для администраторов);
  * Поиск заметки по заголовку на главной странице;
  * Каптча при авторизации/регистрации;
  * Система инвайт-кодов (не обязательно);
  * Поддержка отдельных опций для каждой платформы;
  * Спецификаторы доступа заметки (для всех, для пользователей, для себя);
  * Создание/Удаление тэгов, возможность пользователя выбрать нужные тэги (результат отображается в RSS);
  * Возможность добавления комментариев к записи;
  * Просмотр статистики зарегистрированных пользователей (только для администраторов);
  * Twitter-style feed;

## Баги и некоторые особенности
Особенности:
* [ANY] Если удалить канал, а затем удалить пост, то пост из платформ не удалится (нет токенов - нет удаления, вроде логично);
* [TG] Если у поста в telegram был текст и аттачменты, и при редактировании убрать все аттачменты, то пост полностью удалится. Это особенность телеги, я не могу превратить подпись в текст, нужно создавать новый пост;
* [TG] Если вы отправляете несколько аттачментов разного типа и используете подпись, то аттачменты будут сгруппированы по группам, первой группой будет такого же типа как и первый аттачмент, и подпись будет прикреплена именно к ней;
* [TG] Если был создан пост с <= 4096 символами и при обновлении поста его длина будет превышать 4096 символов, то будет создано новое сообщение, которое может быть на дальнем расстоянии от первого (например, если были ещё посты то оно будет идти после них). Переместить сообщение вверх я не могу, поэтому советую использовать опцию onlylink в таких случаях;

Баги:

* [TG] При редактировании аттачментов в комментариях (добавление нового и удаление старого) сбивается порядок и при повторном редактировании удаляется не та картинка;

Если решите их пофиксить, то с радостью приму Pull Request;

## Схемы и скриншоты
ER-диаграмма:
<img src="https://i.imgur.com/RQQCRpa.jpeg"></img>
Главные страницы (настраивается):
 * Вариант 0 (отдельная страница):
<img src="https://i.imgur.com/cVz0Quv.png"></img>
 * Вариант 1 [По-умолчанию] (posts):
 <img src="https://i.imgur.com/j6FCqsv.png"></img>
 * Вариант 2: (feed):
 <img src="https://i.imgur.com/FJ7z6vF.png"></img>

Личный кабинет:
<img src="https://i.imgur.com/XDwP5n0.png"></img>
Управление каналами:
<img src="https://i.imgur.com/ojERlTd.png"></img>
Инвайт-коды:
<img src="https://i.imgur.com/FvAlzzT.png"></img>
Статистика:
<img src="https://i.imgur.com/WxAdMuD.png"></img>
Создание статьи (Default theme):
<img src="https://i.imgur.com/3QStroz.png"></img>
Конкретная статья:
<img src="https://i.imgur.com/9F0W2Nr.png"></img>

## Связь
Если у Вас есть вопросы, идеи или собственные наработки, то всегда можете обратиться ко мне по следующему адресу:

- [Matrix](https://matrix.to/#/@whiletruedoend:matrix.org)