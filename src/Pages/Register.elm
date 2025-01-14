module Pages.Register exposing (Model, Msg, Params, page)

import Browser.Navigation as Nav exposing (Key, pushUrl)
import Components.Validity exposing (containsChar, containsDigit, containsLowerCase, containsUpperCase, isValidEmail, isValidPassword)
import Html exposing (a, br, button, div, h1, i, input, li, p, text, time, ul)
import Html.Attributes exposing (class, href, id, placeholder, style, type_, value)
import Html.Events exposing (onClick, onInput)
import Http exposing (..)
import Iso8601
import Json.Decode as D exposing (field)
import Json.Encode as E exposing (..)
import Server
import Shared
import Spa.Document exposing (Document)
import Spa.Generated.Route as Route
import Spa.Page as Page exposing (Page)
import Spa.Url exposing (Url)
import String.Extra
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
    ()


type alias Model =
    { email : String
    , password : String
    , passwordAgain : String
    , firstname : String
    , lastname : String
    , warning : String
    , key : Key
    }


init : Shared.Model -> Url Params -> ( Model, Cmd Msg )
init shared { params } =
    case shared.user of
        Just u ->
            ( { email = "", password = "", passwordAgain = "", firstname = "", lastname = "", warning = "", key = shared.key }, pushUrl shared.key "/" )

        Nothing ->
            ( { email = "", password = "", passwordAgain = "", firstname = "", lastname = "", warning = "", key = shared.key }, Cmd.none )



-- UPDATE


type Msg
    = FirstName String
    | LastName String
    | Password String
    | PasswordAgain String
    | Email String
    | GetTime (Time.Posix -> Msg)
    | Submit Time.Posix
    | Response (Result Http.Error String)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FirstName firstname ->
            ( { model | firstname = firstname, warning = "" }, Cmd.none )

        LastName lastname ->
            ( { model | lastname = lastname, warning = "" }, Cmd.none )

        Email email ->
            ( { model | email = email, warning = "" }, Cmd.none )

        Password password ->
            ( { model | password = password, warning = "" }, Cmd.none )

        PasswordAgain password ->
            ( { model | passwordAgain = password, warning = "" }, Cmd.none )

        Submit time ->
            if String.isEmpty model.firstname then
                ( { model | warning = "Enter your first name!" }, Cmd.none )

            else if String.isEmpty model.lastname then
                ( { model | warning = "Enter your last name!" }, Cmd.none )

            else if String.isEmpty model.email then
                ( { model | warning = "Enter your email!" }, Cmd.none )

            else if isValidEmail model.email /= True then
                ( { model | warning = "Enter a valid email!" }, Cmd.none )

            else if String.isEmpty model.password then
                ( { model | warning = "Enter your password!" }, Cmd.none )

            else if isValidPassword model.password /= True then
                ( { model | warning = "Enter a valid password" }, Cmd.none )

            else if String.isEmpty model.passwordAgain then
                ( { model | warning = "Enter your password again!" }, Cmd.none )

            else if model.password /= model.passwordAgain && String.length model.passwordAgain > 0 then
                ( { model | warning = "Passwords do not match!" }, Cmd.none )

            else
                ( { model | warning = "Loading..." }, registerUser time model )

        GetTime time ->
            ( model, Task.perform time Time.now )

        Response response ->
            case response of
                Ok value ->
                    ( { model | warning = "Successfully registered!" }, Nav.pushUrl model.key "/login" )

                Err err ->
                    ( { model | warning = httpErrorString err }, Cmd.none )


httpErrorString : Http.Error -> String
httpErrorString error =
    case error of
        BadUrl text ->
            "Bad Url: " ++ text

        Timeout ->
            "Http Timeout"

        NetworkError ->
            "Connection issues"

        BadStatus response ->
            case response of
                400 ->
                    "Email taken!"

                _ ->
                    "Something went wrong!"

        _ ->
            "Something went wrong!"


save : Model -> Shared.Model -> Shared.Model
save model shared =
    shared


load : Shared.Model -> Model -> ( Model, Cmd Msg )
load shared model =
    ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Document Msg
view model =
    { title = "Sign Up | GoodFood"
    , body =
        [ div []
            [ h1 [] [ text "Sign Up" ]
            , div [ class "input__container" ]
                [ input
                    [ id "firstname"
                    , type_ "text"
                    , placeholder "First Name"
                    , value model.firstname
                    , onInput FirstName
                    , class "form"
                    ]
                    []
                , if String.isEmpty model.firstname then
                    i [ class "check" ] []

                  else
                    i [ class "fas fa-check", class "green__check" ] []
                ]
            , div [ class "input__container" ]
                [ input
                    [ id "lastname"
                    , type_ "text"
                    , placeholder "Last Name"
                    , value model.lastname
                    , onInput LastName
                    , class "form"
                    ]
                    []
                , if String.isEmpty model.lastname then
                    i [ class "check" ] []

                  else
                    i [ class "fas fa-check", class "green__check" ] []
                ]
            , div [ class "input__container" ]
                [ input
                    [ id "email"
                    , type_ "email"
                    , placeholder "Email"
                    , value model.email
                    , onInput Email
                    , class "form"
                    ]
                    []
                , if String.isEmpty model.email then
                    i [ class "check" ] []

                  else if isValidEmail model.email then
                    i [ class "fas fa-check", class "green__check" ] []

                  else
                    i [ class "fas fa-times", class "red__check" ] []
                ]
            , div [ class "input__container" ]
                [ input
                    [ id "password"
                    , type_ "password"
                    , placeholder "Password"
                    , value model.password
                    , onInput Password
                    , class "form"
                    ]
                    []
                , if String.isEmpty model.password then
                    i [ class "check" ] []

                  else if isValidPassword model.password then
                    i [ class "fas fa-check", class "green__check" ] []

                  else
                    i [ class "fas fa-times", class "red__check" ] []
                ]
            , div [ class "input__container" ]
                [ input
                    [ id "passwordAgain"
                    , type_ "password"
                    , placeholder "Password Again"
                    , value model.passwordAgain
                    , onInput PasswordAgain
                    , class "form"
                    ]
                    []
                , if String.isEmpty model.passwordAgain then
                    i [ class "check" ] []

                  else if model.password == model.passwordAgain then
                    i [ class "fas fa-check", class "green__check" ] []

                  else
                    i [ class "fas fa-times", class "red__check" ] []
                ]
            , if isValidPassword model.password || String.isEmpty model.password then
                div [ class "warner" ] []

              else
                div [ class "warner" ]
                    [ p [] [ text "Password requirements:" ]
                    , ul []
                        [ li
                            [ class "req__items"
                            , if containsUpperCase model.password then
                                style "color" "#4CAF50"

                              else
                                style "color" "#ff4b4b"
                            ]
                            [ text "Must contain of at least one uppercase letter" ]
                        , li
                            [ class "req__items"
                            , if containsLowerCase model.password then
                                style "color" "#4CAF50"

                              else
                                style "color" "#ff4b4b"
                            ]
                            [ text "Must contain of at least one lowercase letter" ]
                        , li
                            [ class "req__items"
                            , if containsDigit model.password then
                                style "color" "#4CAF50"

                              else
                                style "color" "#ff4b4b"
                            ]
                            [ text "Must contain of at least one digit" ]
                        , li
                            [ class "req__items"
                            , if containsChar model.password then
                                style "color" "#4CAF50"

                              else
                                style "color" "#ff4b4b"
                            ]
                            [ text "Must contain of at least one special character" ]
                        , li
                            [ class "req__items"
                            , if String.length model.password > 7 then
                                style "color" "#4CAF50"

                              else
                                style "color" "#ff4b4b"
                            ]
                            [ text "Password's minimum lenght is 8 characters" ]
                        ]
                    ]
            , div []
                [ button [ class "submit_button", onClick <| GetTime Submit ] [ text "Sign Up" ] ]
            , div [ class "warning_form" ]
                [ text model.warning ]
            , div []
                [ br [] []
                , a [ class "link", href (Route.toString Route.Login) ] [ text "Have an account?" ]
                ]
            ]
        ]
    }


registerUser : Time.Posix -> Model -> Cmd Msg
registerUser nowTime model =
    let
        body =
            [ ( "firstname", E.string <| String.Extra.toSentenceCase <| String.toLower <| String.trim <| model.firstname )
            , ( "lastname", E.string <| String.Extra.toSentenceCase <| String.toLower <| String.trim <| model.lastname )
            , ( "password", E.string model.password )
            , ( "email", E.string <| String.trim <| model.email )
            , ( "bio", E.string "I am new here..." )
            , ( "image", E.string "/assets/user_default.png" )
            , ( "created", Iso8601.encode nowTime )
            ]
                |> E.object
                |> Http.jsonBody
    in
    Http.request
        { method = "POST"
        , headers = []
        , url = Server.url ++ "/users"
        , body = body
        , expect = Http.expectJson Response (field "accessToken" D.string)
        , timeout = Nothing
        , tracker = Nothing
        }
