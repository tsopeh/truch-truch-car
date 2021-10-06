module Main exposing (..)

import Api
import AppLayout
import Browser exposing (UrlRequest(..))
import Browser.Navigation as Nav
import Html
import I18n
import Image
import Json.Decode as JD
import Json.Encode as JE
import Page.Home as Home
import Page.Login as Login
import Page.Offer as Offer
import Page.Register as Register
import Page.Suggestions as Suggestions
import Page.User as User
import Route as Route exposing (Route)
import State
import Task
import Time
import Url
import Viewer



{- TODO:
   - 404 page
   - Create offer page (from driver's perspective)
   - Preview all associated drives from the Passenger's perspective and from
     the Driver's perspective
   - Preview Passengers contact information from offer's detailed view.
   - Redirect user if not logged in.
-}
-- MODEL


type Model
    = Redirect State.Model
    | Home Home.Model
    | Suggestions Suggestions.Model
    | Offer Offer.Model
    | User User.Model
    | Login Login.Model
    | Register Register.Model


toState : Model -> State.Model
toState model =
    case model of
        Redirect state ->
            state

        Home homeModel ->
            homeModel.state

        Suggestions suggestionsModel ->
            suggestionsModel.state

        Offer offerModel ->
            offerModel.state

        User userModel ->
            userModel.state

        Login loginModel ->
            loginModel.state

        Register register ->
            register.state


updateState : Model -> State.Model -> Model
updateState model state =
    case model of
        Redirect _ ->
            Redirect state

        Home homeModel ->
            Home <| { homeModel | state = state }

        Suggestions suggestionsModel ->
            Suggestions <| { suggestionsModel | state = state }

        Offer offerModel ->
            Offer <| { offerModel | state = state }

        User userModel ->
            User <| { userModel | state = state }

        Login loginModel ->
            Login <| { loginModel | state = state }

        Register register ->
            Register <| { register | state = state }



-- UPDATE


type Msg
    = UrlRequested Browser.UrlRequest
    | UrlChanged Url.Url
    | LanguageChanged I18n.Language
    | GotToken (Maybe Api.Token)
    | GotHereZone Time.Zone
    | GotFromAppLayout (AppLayout.Msg Msg)
    | GotHomeMsg Home.Msg
    | GotSuggestionMsg Suggestions.Msg
    | GotOfferMsg Offer.Msg
    | GotUserMsg User.Msg
    | GotLoginMsg Login.Msg
    | GotRegisterMsg Register.Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update mainMsg mainModel =
    case ( mainMsg, mainModel ) of
        ( UrlRequested urlRequest, _ ) ->
            case urlRequest of
                Internal url ->
                    let
                        key =
                            toState mainModel |> .navKey
                    in
                    ( mainModel, Nav.pushUrl key (Url.toString url) )

                External url ->
                    ( mainModel, Nav.load url )

        ( UrlChanged url, _ ) ->
            changeModelTo (Route.fromUrl url) mainModel

        ( LanguageChanged language, _ ) ->
            let
                state =
                    toState mainModel

                updatedModel =
                    updateState mainModel { state | language = language }
            in
            ( updatedModel, Cmd.none )

        ( GotHereZone zone, _ ) ->
            let
                state =
                    toState mainModel

                updated =
                    updateState mainModel <| { state | timeZone = zone }
            in
            ( updated, Cmd.none )

        ( GotFromAppLayout msg, _ ) ->
            case msg of
                AppLayout.GotFromContent contentMsg ->
                    update contentMsg mainModel

                AppLayout.LanguageChanged languageStringId ->
                    ( mainModel, I18n.persistLanguage languageStringId )

        ( GotToken maybeToken, _ ) ->
            let
                state =
                    toState mainModel

                updatedModel =
                    updateState mainModel { state | viewer = Viewer.createViewer Image.guestAvatar maybeToken }
            in
            ( updatedModel, Route.navTo state.navKey Route.Home )

        ( GotHomeMsg msg, Home model ) ->
            let
                ( updatedModel, cmd ) =
                    Home.update msg model
            in
            ( Home updatedModel, Cmd.map GotHomeMsg cmd )

        ( GotSuggestionMsg msg, Suggestions model ) ->
            let
                ( updatedModel, cmd ) =
                    Suggestions.update msg model
            in
            ( Suggestions updatedModel, Cmd.map GotSuggestionMsg cmd )

        ( GotOfferMsg msg, Offer model ) ->
            let
                ( updatedModel, cmd ) =
                    Offer.update msg model
            in
            ( Offer updatedModel, Cmd.map GotOfferMsg cmd )

        ( GotUserMsg userMsg, User userModel ) ->
            let
                ( updatedModel, cmd ) =
                    User.update userMsg userModel
            in
            ( User updatedModel, Cmd.map GotUserMsg cmd )

        ( GotLoginMsg loginMsg, Login loginModel ) ->
            let
                ( updatedModel, cmd ) =
                    Login.update loginMsg loginModel
            in
            ( Login updatedModel, Cmd.map GotLoginMsg cmd )

        ( GotRegisterMsg registerMsg, Register registerModel ) ->
            let
                ( updatedModel, cmd ) =
                    Register.update registerMsg registerModel
            in
            ( Register updatedModel, Cmd.map GotRegisterMsg cmd )

        ( _, _ ) ->
            let
                _ =
                    Debug.log "Impossible state" ( mainMsg, mainModel )
            in
            ( mainModel, Cmd.none )


changeModelTo : Maybe Route -> Model -> ( Model, Cmd Msg )
changeModelTo maybeRoute mainModel =
    let
        state =
            toState mainModel
    in
    case maybeRoute of
        Nothing ->
            ( mainModel, Route.navTo state.navKey Route.Home )

        Just Route.Home ->
            mapInit Home GotHomeMsg <| Home.init state

        Just (Route.Suggestions startId finishId depDateTime) ->
            mapInit Suggestions GotSuggestionMsg <| Suggestions.init state startId finishId (Time.millisToPosix depDateTime)

        Just (Route.Offer offerId) ->
            mapInit Offer GotOfferMsg <| Offer.init state offerId

        Just (Route.User id) ->
            mapInit User GotUserMsg <| User.init state id

        Just Route.Login ->
            mapInit Login GotLoginMsg <| Login.init state

        Just Route.Logout ->
            ( Redirect state, Api.logout )

        Just Route.Register ->
            mapInit Register GotRegisterMsg <| Register.init state


mapInit : (subModel -> Model) -> (msg -> Msg) -> ( subModel, Cmd msg ) -> ( Model, Cmd Msg )
mapInit mapModel mapMsg ( subModel, cmd ) =
    ( mapModel subModel, Cmd.map mapMsg cmd )



-- VIEW


view : Model -> Browser.Document Msg
view mainModel =
    let
        content : Html.Html Msg
        content =
            case mainModel of
                Redirect _ ->
                    Html.div [] [ Html.text "Redirecting..." ]

                Home homeModel ->
                    Html.map GotHomeMsg <| Home.view homeModel

                Suggestions suggestionModel ->
                    Html.map GotSuggestionMsg <| Suggestions.view suggestionModel

                Offer offerModel ->
                    Html.map GotOfferMsg <| Offer.view offerModel

                User userModel ->
                    Html.map GotUserMsg <| User.view userModel

                Login loginModel ->
                    Html.map GotLoginMsg <| Login.view loginModel

                Register registerModel ->
                    Html.map GotRegisterMsg <| Register.view registerModel

        body =
            List.map (Html.map GotFromAppLayout) (AppLayout.view (AppLayout.init (toState mainModel)) content)
    in
    { title = "Title"
    , body = body
    }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        updateLang : JE.Value -> Msg
        updateLang raw =
            let
                language =
                    case JD.decodeValue I18n.languageDecoder raw of
                        Ok lang ->
                            lang

                        _ ->
                            I18n.Eng
            in
            LanguageChanged language

        updateToken : JE.Value -> Msg
        updateToken raw =
            GotToken (JD.decodeValue Api.decodeToken raw |> Result.toMaybe)
    in
    Sub.batch
        [ Sub.map GotHomeMsg (Home.receiveSearchFormFromStorage Home.GotFormFromStorage)
        , I18n.languageChanged updateLang
        , Api.tokenChanged updateToken
        ]



-- MAIN


init : JE.Value -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        language : I18n.Language
        language =
            case JD.decodeValue (JD.field "language" I18n.languageDecoder) flags of
                Ok lang ->
                    lang

                Err err ->
                    let
                        _ =
                            Debug.log "Falling back to Eng. Failed to decode language" err
                    in
                    I18n.Eng

        maybeToken =
            JD.decodeValue (JD.field "token" Api.decodeToken) flags |> Result.toMaybe

        viewer : State.Model
        viewer =
            { viewer = Viewer.createViewer Image.guestAvatar maybeToken
            , navKey = key
            , timeZone = Time.utc
            , language = language
            }

        ( model, cmd ) =
            changeModelTo (Route.fromUrl url) <| Redirect viewer
    in
    ( model
    , Cmd.batch
        [ Task.perform GotHereZone Time.here
        , cmd
        ]
    )


main : Program JE.Value Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = UrlRequested
        , onUrlChange = UrlChanged
        }
