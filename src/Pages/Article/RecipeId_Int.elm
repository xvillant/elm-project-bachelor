module Pages.Article.RecipeId_Int exposing (Model, Msg, Params, page)

import Api.Article exposing (Article, articleDecoder)
import Api.Comment exposing (Comment, commentDecoder, commentsDecoder)
import Api.Data exposing (Data(..), viewFetchError)
import Api.User exposing (User)
import Browser.Navigation exposing (Key, pushUrl)
import Components.TimeFormatting exposing (formatDate, formatTime)
import Html exposing (..)
import Html.Attributes exposing (class, cols, href, placeholder, rows, src, width)
import Html.Events exposing (onClick, onInput)
import Http exposing (..)
import Iso8601
import Json.Encode as E exposing (..)
import Server
import Shared
import Spa.Document exposing (Document)
import Spa.Page as Page exposing (Page)
import Spa.Url exposing (Url)
import Task
import Time


page : Page Params Model Msg
page =
    Page.application
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        , save = save
        , load = load
        }



-- INIT


type alias Params =
    { recipeId : Int }


type alias Model =
    { article : Data Article
    , comments : Data (List Comment)
    , commentString : String
    , warning : String
    , zone : Time.Zone
    , key : Key
    , user : Maybe User
    , parameters : Params
    }


init : Shared.Model -> Url Params -> ( Model, Cmd Msg )
init shared { params } =
    case shared.user of
        Just user_ ->
            ( { article = Loading
              , commentString = ""
              , comments = Loading
              , warning = ""
              , zone = Time.utc
              , user = shared.user
              , key = shared.key
              , parameters = params
              }
            , Cmd.batch [ getArticleRequest user_.token params { onResponse = ReceivedArticle }, getCommentsRequest user_.token params { onResponse = CommentsReceived }, Task.perform TimeZone Time.here ]
            )

        Nothing ->
            ( { article = Loading
              , commentString = ""
              , comments = Loading
              , warning = ""
              , zone = Time.utc
              , user = Nothing
              , key = shared.key
              , parameters = params
              }
            , pushUrl shared.key "/login"
            )



-- UPDATE


type Msg
    = ReceivedArticle (Data Article)
    | CommentsReceived (Data (List Comment))
    | AddComment String
    | SubmitComment Time.Posix
    | GetTime (Time.Posix -> Msg)
    | TimeZone Time.Zone
    | CommentResponse (Data Comment)
    | Tick Time.Posix
    | DeleteArticle Int
    | DeleteResponse (Result Http.Error String)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ReceivedArticle response ->
            ( { model | article = response }, Cmd.none )

        CommentsReceived response ->
            ( { model | comments = response }, Cmd.none )

        AddComment comment ->
            ( { model | commentString = comment, warning = "" }, Cmd.none )

        SubmitComment time ->
            if String.isEmpty model.commentString then
                ( { model | warning = "Type your comment!" }, Cmd.none )

            else
                ( { model | commentString = "" }
                , postComment time model { onResponse = CommentResponse }
                )

        TimeZone tz ->
            ( { model | zone = tz }, Cmd.none )

        GetTime time ->
            ( model, Task.perform time Time.now )

        CommentResponse comment ->
            ( case comment of
                Success c ->
                    { model | comments = Api.Data.map (\comments -> c :: comments) model.comments, commentString = "", warning = "" }

                _ ->
                    model
            , Cmd.none
            )

        Tick time ->
            ( model
            , getCommentsRequest
                (case model.user of
                    Just u ->
                        u.token

                    Nothing ->
                        ""
                )
                model.parameters
                { onResponse = CommentsReceived }
            )

        DeleteArticle articleid ->
            ( model
            , deleteArticle
                (case model.user of
                    Just u ->
                        u.token

                    Nothing ->
                        ""
                )
                articleid
            )

        DeleteResponse deleted ->
            case deleted of
                Ok value ->
                    ( model, pushUrl model.key "/recipes" )

                Err _ ->
                    ( { model | warning = "Delete unsuccessful!" }, Cmd.none )


save : Model -> Shared.Model -> Shared.Model
save model shared =
    shared


load : Shared.Model -> Model -> ( Model, Cmd Msg )
load shared model =
    ( { model | user = shared.user }, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Time.every 30000 Tick



-- VIEW


view : Model -> Document Msg
view model =
    case model.article of
        Success article ->
            { title = "Article | " ++ article.name ++ " | GoodFood"
            , body =
                [ viewArticle model
                , div [ class "warning_form" ] [ text model.warning ]
                , viewComments model
                ]
            }

        _ ->
            { title = "Article | GoodFood"
            , body =
                [ viewArticle model
                , div [ class "warning_form" ] [ text model.warning ]
                , viewComments model
                ]
            }


getArticleRequest : String -> Params -> { onResponse : Data Article -> Msg } -> Cmd Msg
getArticleRequest tokenString params options =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" ("Bearer " ++ tokenString) ]
        , url = Server.url ++ "/posts/" ++ String.fromInt params.recipeId
        , body = Http.emptyBody
        , expect = Api.Data.expectJson options.onResponse articleDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


getCommentsRequest : String -> Params -> { onResponse : Data (List Comment) -> Msg } -> Cmd Msg
getCommentsRequest tokenString params options =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" ("Bearer " ++ tokenString) ]
        , url = Server.url ++ "/comments?postId=" ++ String.fromInt params.recipeId ++ "&_sort=created&_order=desc"
        , body = Http.emptyBody
        , expect = Api.Data.expectJson options.onResponse commentsDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


viewComments : Model -> Html Msg
viewComments model =
    case model.comments of
        Success actualComments ->
            let
                tzarray =
                    List.repeat (List.length actualComments) model.zone
            in
            if List.isEmpty actualComments then
                div []
                    [ h2 [] [ text "Comments" ]
                    , div [ class "line_after_recipes" ] []
                    , div [ class "comments_list" ]
                        [ br [] []
                        , p [ class "err" ] [ text "No comments yet..." ]
                        ]
                    ]

            else
                div []
                    [ h2 [] [ text "Comments" ]
                    , div [ class "line_after_recipes" ] []
                    , div [ class "comments_list" ]
                        (List.map2 viewComment actualComments tzarray)
                    ]

        _ ->
            text ""


viewComment : Comment -> Time.Zone -> Html Msg
viewComment comment tz =
    ul []
        [ li [ class "comment_value" ]
            [ text comment.comment ]
        , li [ class "value" ]
            [ p [ class "datetime" ] [ text (formatDate tz comment.created) ]
            , p [ class "datetime" ] [ text (formatTime tz comment.created) ]
            ]
        , a [ class "link", href ("/profile/" ++ String.fromInt comment.userId) ] [ text comment.fullname ]
        , div [ class "line_after_recipes" ] []
        ]


postComment : Time.Posix -> Model -> { onResponse : Data Comment -> Msg } -> Cmd Msg
postComment nowTime model options =
    let
        body =
            [ ( "comment", E.string model.commentString )
            , ( "postId"
              , E.int
                    (case model.article of
                        Success article ->
                            article.id

                        _ ->
                            0
                    )
              )
            , ( "fullname"
              , E.string
                    (case model.user of
                        Just user ->
                            user.firstname ++ " " ++ user.lastname

                        Nothing ->
                            ""
                    )
              )
            , ( "created", Iso8601.encode nowTime )
            , ( "userId"
              , E.int
                    (case model.user of
                        Just u ->
                            u.id

                        Nothing ->
                            0
                    )
              )
            ]
                |> E.object
                |> Http.jsonBody
    in
    Http.request
        { method = "POST"
        , headers =
            [ Http.header "Authorization"
                ("Bearer "
                    ++ (case model.user of
                            Just u ->
                                u.token

                            Nothing ->
                                ""
                       )
                )
            ]
        , url = Server.url ++ "/comments"
        , body = body
        , expect = Api.Data.expectJson options.onResponse commentDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


viewArticle : Model -> Html Msg
viewArticle model =
    case model.article of
        NotAsked ->
            text ""

        Loading ->
            div []
                [ img [ src "/assets/loading.gif" ] [] ]

        Success value ->
            div []
                [ div [] [ h1 [] [ text value.name ] ]
                , div []
                    [ p [ class "datetime" ] [ text (formatDate model.zone value.created) ]
                    , p [ class "datetime" ] [ text (formatTime model.zone value.created) ]
                    ]
                , div []
                    [ p [ class "title" ] [ text "shared by " ]
                    , a [ class "link", href ("/profile/" ++ String.fromInt value.userId) ] [ text value.fullname ]
                    ]
                , div [] [ img [ class "recipe__image", src value.image, width 500 ] [] ]
                , div []
                    [ p [ class "title" ] [ text "ingredients " ]
                    , div [ class "justify__content" ]
                        [ p [ class "value" ] [ renderList value.ingredients ]
                        ]
                    ]
                , div []
                    [ p [ class "title" ] [ text "recipe " ]
                    , div [ class "justify__content__recipe" ]
                        [ p [ class "value" ] [ text value.recipe ] ]
                    ]
                , div []
                    [ p [ class "title" ] [ text "duration" ]
                    , p [ class "value" ]
                        [ text <| String.fromInt value.duration ++ " minutes" ]
                    ]
                , if
                    value.userId
                        == (case model.user of
                                Just u ->
                                    u.id

                                Nothing ->
                                    0
                           )
                  then
                    button [ class "recipe_delete_button", onClick <| DeleteArticle value.id ] [ text "Delete recipe" ]

                  else
                    text ""
                , div []
                    [ textarea [ placeholder "Type your comment here...", cols 70, rows 10, Html.Attributes.value model.commentString, onInput AddComment, class "form" ] []
                    ]
                , div []
                    [ button [ class "submit_button", onClick <| GetTime SubmitComment ] [ text "Share comment" ]
                    ]
                ]

        Failure failures ->
            viewFetchError "article" failures


renderList : List String -> Html msg
renderList lst =
    ol [ class "ingredients__" ]
        (List.map (\l -> li [ class "value" ] [ text l ]) lst)


deleteArticle : String -> Int -> Cmd Msg
deleteArticle tokenString articleid =
    Http.request
        { method = "DELETE"
        , headers = [ Http.header "Authorization" ("Bearer " ++ tokenString) ]
        , url = Server.url ++ "/posts/" ++ String.fromInt articleid
        , body = Http.emptyBody
        , expect = expectString DeleteResponse
        , timeout = Nothing
        , tracker = Nothing
        }
