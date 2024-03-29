port module Page.Home exposing (..)

import Html exposing (Html, button, div, form, input, text)
import Html.Attributes exposing (class, type_, value)
import Html.Events exposing (onInput, onSubmit)
import Http
import I18n
import Iso8601
import Json.Decode as JD
import Json.Decode.Pipeline as JDP
import Json.Encode as JE
import Location exposing (Location, LocationId, getAllLocations)
import Route
import SearchSelect
import State
import SvgIcons exposing (search)
import Task exposing (Task)
import Time
import Utils exposing (Status(..), posixToIsoDate)



-- MODEL


type alias Model =
    { state : State.Model
    , locations : Status (List Location)
    , formModel : FormModel
    }


type alias FormModel =
    { startSelect : SearchSelect.Model
    , finishSelect : SearchSelect.Model
    , departureDateTime : Time.Posix
    , problems : List String
    }



-- UPDATE


type Msg
    = GotStartSelectMsg SearchSelect.Msg
    | GotFinishSelectMsg SearchSelect.Msg
    | DepartureDateTimeChanged Time.Posix
    | Submit
    | GotLocations (Result Http.Error (List Location))
    | GotNowTime Time.Posix
    | GotFormFromStorage JE.Value


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotStartSelectMsg selectMsg ->
            let
                form =
                    model.formModel

                ( updatedSearchModel, searchSelectCmd ) =
                    SearchSelect.update selectMsg form.startSelect
            in
            ( { model | formModel = { form | startSelect = updatedSearchModel } }, Cmd.map GotStartSelectMsg searchSelectCmd )

        GotFinishSelectMsg selectMsg ->
            let
                form =
                    model.formModel

                ( updatedSearchModel, searchSelectCmd ) =
                    SearchSelect.update selectMsg form.finishSelect
            in
            ( { model | formModel = { form | finishSelect = updatedSearchModel } }, Cmd.map GotFinishSelectMsg searchSelectCmd )

        DepartureDateTimeChanged change ->
            let
                form =
                    model.formModel
            in
            ( { model | formModel = { form | departureDateTime = change } }, Cmd.none )

        Submit ->
            let
                startId =
                    (case model.formModel.startSelect.selectedOption of
                        Nothing ->
                            "N/A"

                        Just id ->
                            id
                    )
                        |> Location.stringToId

                finishId =
                    (case model.formModel.finishSelect.selectedOption of
                        Nothing ->
                            "N/A"

                        Just id ->
                            id
                    )
                        |> Location.stringToId

                dateTime =
                    Time.posixToMillis model.formModel.departureDateTime
            in
            ( model
            , Cmd.batch
                [ persistSearchForm <| encodeForm model.formModel
                , Route.navTo model.state.navKey (Route.Suggestions startId finishId dateTime)
                ]
            )

        GotLocations result ->
            case result of
                Ok locations ->
                    let
                        form =
                            model.formModel

                        departureSearchSelect =
                            form.startSelect

                        arrivalSearchSelect =
                            form.finishSelect

                        options =
                            List.map (\s -> { id = Location.idToString s.id, value = s.name }) locations
                    in
                    ( { model
                        | locations = Loaded locations
                        , formModel =
                            { form
                                | startSelect =
                                    { departureSearchSelect
                                        | options = options
                                    }
                                , finishSelect =
                                    { arrivalSearchSelect
                                        | options = options
                                    }
                            }
                      }
                    , Cmd.none
                    )

                Err _ ->
                    ( { model | locations = Failed }, Cmd.none )

        GotNowTime time ->
            case Time.posixToMillis time > Time.posixToMillis model.formModel.departureDateTime of
                True ->
                    update (DepartureDateTimeChanged time) model

                False ->
                    ( model, Cmd.none )

        GotFormFromStorage raw ->
            let
                updatedModel =
                    case JD.decodeValue formStorageModelDecoder raw of
                        Ok formStorageModel ->
                            let
                                newFormModel =
                                    updateFormModelWithFormPersistenceModel model.formModel formStorageModel
                            in
                            ( { model | formModel = newFormModel }, Cmd.none )

                        Err err ->
                            let
                                _ =
                                    Debug.log "err" err
                            in
                            ( model, Cmd.none )
            in
            updatedModel



-- View


view : Model -> Html Msg
view { state, locations, formModel } =
    let
        t =
            State.toI18n state
    in
    case locations of
        Loading ->
            text <| t I18n.LoadingLocations

        Loaded _ ->
            div [ class "home-page" ]
                [ form [ onSubmit Submit ]
                    [ div [ class "fields" ]
                        [ Html.map GotStartSelectMsg <|
                            SearchSelect.view formModel.startSelect
                        , Html.map GotFinishSelectMsg <|
                            SearchSelect.view formModel.finishSelect
                        , viewDateTime DepartureDateTimeChanged state.timeZone formModel.departureDateTime
                        ]
                    , button [ type_ "submit" ] [ search ]
                    ]
                ]

        Failed ->
            text <| t I18n.FailedToLoadLocations


viewDateTime : (Time.Posix -> Msg) -> Time.Zone -> Time.Posix -> Html Msg
viewDateTime msg zone posix =
    let
        msgStringToPosix : String -> Msg
        msgStringToPosix str =
            case Iso8601.toTime str of
                Ok parsedPosix ->
                    msg parsedPosix

                Err _ ->
                    msg posix
    in
    input [ type_ "date", class "date-input", onInput msgStringToPosix, value <| posixToIsoDate zone posix ] []



-- INIT


init : State.Model -> ( Model, Cmd Msg )
init state =
    ( { state = state
      , locations = Loading
      , formModel = initForm (State.toI18n state)
      }
    , Cmd.batch
        [ Task.perform GotNowTime Time.now
        , requestSearchFormFromStorage ()
        , Task.attempt GotLocations (getAllLocations state.viewer)
        ]
    )


initForm : I18n.TranslationFn -> FormModel
initForm t =
    { startSelect =
        { search = ""
        , options = []
        , selectedOption = Nothing
        , isFocused = False
        , placeholder = t I18n.LeavingFrom
        }
    , finishSelect =
        { search = ""
        , options = []
        , selectedOption = Nothing
        , isFocused = False
        , placeholder = t I18n.GoingTo
        }
    , departureDateTime = Time.millisToPosix 0
    , problems = []
    }



-- ENCODE


encodeForm : FormModel -> JE.Value
encodeForm formModel =
    JE.object
        [ ( "departureStationId"
          , formModel.startSelect.selectedOption
                |> Maybe.map JE.string
                |> Maybe.withDefault JE.null
          )
        , ( "arrivalStationId"
          , formModel.finishSelect.selectedOption
                |> Maybe.map JE.string
                |> Maybe.withDefault JE.null
          )
        , ( "departureDateTime", JE.int <| Time.posixToMillis formModel.departureDateTime )
        ]


type alias FormStorageModel =
    { departureStationId : Maybe String
    , arrivalStationId : Maybe String
    , departureDateTime : Int
    }


formStorageModelDecoder : JD.Decoder FormStorageModel
formStorageModelDecoder =
    JD.succeed FormStorageModel
        |> JDP.optional "departureStationId" (JD.map Just JD.string) Nothing
        |> JDP.optional "arrivalStationId" (JD.map Just JD.string) Nothing
        |> JDP.required "departureDateTime" JD.int


updateFormModelWithFormPersistenceModel : FormModel -> FormStorageModel -> FormModel
updateFormModelWithFormPersistenceModel formModel formPersistenceModel =
    let
        departureSearchSelect =
            formModel.startSelect

        arrivalSearchSelect =
            formModel.finishSelect

        dateTime =
            formModel.departureDateTime
    in
    { formModel
        | startSelect = { departureSearchSelect | selectedOption = formPersistenceModel.departureStationId }
        , finishSelect = { arrivalSearchSelect | selectedOption = formPersistenceModel.arrivalStationId }
        , departureDateTime =
            case Time.posixToMillis dateTime > formPersistenceModel.departureDateTime of
                True ->
                    dateTime

                False ->
                    Time.millisToPosix formPersistenceModel.departureDateTime
    }



-- PORTS


port persistSearchForm : JE.Value -> Cmd msg


port requestSearchFormFromStorage : () -> Cmd msg


port receiveSearchFormFromStorage : (JE.Value -> msg) -> Sub msg
