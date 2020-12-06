# Twilight

<img src="https://i.imgur.com/Q2Lhx58.png"></img>

## Идея

Недавно задумался над реализацией блогов в разных платформах, и пришёл к следующим проблемам:
 
 * Первая, это то что нет единой площадки куда можно складывать контент;
 * Вторая, проблема в том что все сидят в разных местах;
 
    из этих двух вытекает:
 
 * Третья - глупость самому постить одно и то же в разные места;
 * Четвёртая - нужно самому сидеть в других платформах;
 
 Поэтому было принято написать что-то вроде агрегатора статей. Всё просто - пишешь пост - он разлетается по разным платформам. Схема будет выглядеть примерно так:
 
 <img src="https://i.imgur.com/JvTIBCc.png"></img>
 
 Хочу отметить, это не окончательный вариант, т.е. помимо поста в разные платформы планируется так же реализовать отправку поста в БД, и оттуда по другим платформам. Но сейчас хотя бы сделать так.
 
 На схеме видно что каналы на платформах matrix и jabber принадлежат владельцу, а вот действие с telegram-каналами (или любыми другими) осуществляется с помощью rss токена. Поясняю: каждый зарегистрировавшейся пользователь получает свой токен и использует его для получения новостей с RSS. Это даёт два преимущества:
 
 1) Персонализация с помощью тегов контента, который пользователь хочет видеть;
 2) Ограничение автором прав доступа на некоторые статьи;
 
 Конечно, если мы говорим о размещении статей на других открытых платформах, ограничение прав особо не имеет смысла, однако целью автора не было построение полностью изолированной среды с контролем каждой выходной ноды, хотя бы потому что это практически нереализуемо.
 
 На текущий момент таблица моделей выглядит примерно так:
 
 <img src="https://i.imgur.com/3dHXsix.png"></img>
 
 ## Текущие возможности/Планы
 * <s>Система регистрации/авторизации (devise);</s>
 * <s>Простенькая каптча при регистрации/авторизации;</s>
 * <s>Реализация создания, просмотра постов;</s>
 * <s>Кнопочка 'читать далее' на постах;</s>
 * <s>Поддержка отображения разметки (redcarpet);</s>
 * <s>Тэги для поста и пользователя, возможность настраивать в RSS;</s>
 * <s>Почти красивый markdown-редактор при создании статьи;</s>
 * <s>Починить фронтенд;</s>
 * <s>Удаление тэгов;</s>
 * <s>Оповещение администратору в telegram при регистрации пользователя;</s>
 * <s>Придумать что написать на главной странице;</s>
 * <s>Реализовать пост в telegram;</s>
 * Возможность редактировать статью с дальнейшей отправки правок платформам;
 * Возможность постить и редактировать посты из платформы;
 * Банан за байпасс rss токена;
 * Запрет на посещение сайта с плохими (спам) IP; (???)
 * Система инвайтов; (???)
 * Очень красивый markdown-редактор при создании статьи;
 * Страница помощи для юзера по настройке канала для разных платформ

 
 Список возможно будет пополняться...
 
 ## Установка
 
  * Ставим ruby;
  * Ставим проект: 
  
    ```ssh
     git clone https://github.com/Whiletruedoend/Twilight
     cd Twilight/
     yarn install --check-files
     bundle install
     rails db:migrate
    ```
     
  * Настраиваем: `credentials.yml`
  * Запускаем: `rails s`
  
Теперь сайт будет доступен по адресу: `http://localhost:3080`

## Настройка
Все настройки делаются через консоль (`rails c`)
  * После регистрации делаем себя админом (для публикации постов и всего-всего):
      ```ssh
       User.last.update(is_admin: true)
      ```
  * Создаём платформу (на данный момент поддерживается только telegram)
      ```ssh
       Platform.create(title: "telegram")
      ```
## Контрибьюшен

  1) Форкни проект;
  2) Сделай изменения в форкнутом проекте;
  3) На странице этого репозитория, тыкни Pull Requests и сделай Pull Request, выбрав свой форк в правом списке