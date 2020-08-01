port module Main exposing (main, elm2js, js2elm)

import Browser
import Browser.Navigation as Nav
import Html exposing (Html, text, div, h3, button)
import Html.Events exposing (onClick)
import Json.Encode
import Json.Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (required)
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), Parser)

main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }

-- PORTS
port elm2js : Json.Encode.Value -> Cmd msg
port js2elm : (Json.Decode.Value -> msg) -> Sub msg

type alias PortMsg =
    { tag : String
    , content : String
    }

encodePortMsg : PortMsg -> Json.Encode.Value
encodePortMsg msg
    = Json.Encode.object
        [ ( "tag", Json.Encode.string msg.tag )
        , ( "content", Json.Encode.string msg.content )
        ]

portMsgDecoder : Decoder PortMsg
portMsgDecoder =
    Json.Decode.succeed PortMsg
        |> required "tag" Json.Decode.string
        |> required "content" Json.Decode.string

decodePortMsg : Json.Decode.Value -> Result Json.Decode.Error PortMsg
decodePortMsg msg
    = Json.Decode.decodeValue portMsgDecoder msg

-- MODEL

type Session
    = Session Internals

type alias Internals =
    { key : Nav.Key
    }

createSession : Nav.Key -> Session
createSession key =
    Session (Internals key)

navKeyOf : Session -> Nav.Key
navKeyOf (Session internals) =
    internals.key

type alias SubModel =
    { session: Session
    }

type Model
    = NotFound Session
    | Home Session SubModel
    | Develop Session SubModel

toSession : Model -> Session
toSession model =
    case model of
        NotFound session ->
            session
        
        Home session _ ->
            session
        
        Develop session _ ->
            session

-- ROUTE

type Route
    = HomeRoute
    | DevelopRoute


parser : Parser (Route -> a) a
parser =
    Parser.oneOf
        [ Parser.map HomeRoute Parser.top
        , Parser.map DevelopRoute (Parser.s "develop")
        ]

fromUrl : Url -> Maybe Route
fromUrl url =
    Parser.parse parser url


-- HELPERS

wrapWith : (subModel -> Model) -> (subMsg -> Msg) -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
wrapWith toModel toMsg (subModel, subMsg) =
    ( toModel subModel, Cmd.map toMsg subMsg )

load : Maybe Route -> Model -> ( Model, Cmd Msg )
load maybeRoute model =
    let
        _ = Debug.log "load" maybeRoute
        session =
            toSession model
    in
    case maybeRoute of
        Nothing ->
            ( NotFound session, Cmd.none )

        Just HomeRoute ->
            initHomePage session
                |> wrapWith (Home session) GotHomeMsg

        Just DevelopRoute ->
            initDevelopPage session
                |> wrapWith (Develop session) GotDevelopMsg


-- INIT

type alias Flags
    = Json.Encode.Value

init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        _ = Debug.log "init" (decodePortMsg flags)
    in
    load (fromUrl url) <|
        NotFound (createSession key)

-- UPDATE

type SubMsg
    = NoOps
    | Send

type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | GotHomeMsg SubMsg
    | GotDevelopMsg SubMsg
    | Recv Json.Decode.Value


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    let
        _ = Debug.log "update" message
        session =
            toSession model
    in
    case ( message, model ) of
        ( LinkClicked urlRequest, _ ) ->
            case urlRequest of
                Browser.Internal url ->
                    case fromUrl url of
                        Just _ ->
                            ( model, Nav.pushUrl (navKeyOf session) (Url.toString url) )

                        Nothing ->
                            ( model, Nav.load <| Url.toString url )

                Browser.External href ->
                    if String.length href == 0 then
                        ( model, Cmd.none )

                    else
                        ( model, Nav.load href )

        ( UrlChanged url, _ ) ->
            load (fromUrl url) model

        ( GotHomeMsg msg, Home _ subModel ) ->
            let
                _ = Debug.log "GotHomeMsg" 0
            in
            updateHomePage msg subModel
                |> wrapWith (Home session) GotHomeMsg

        ( GotDevelopMsg msg, Develop _ subModel ) ->
            let
                _ = Debug.log "GotDevelopMsg" 0
            in
            updateDevelopPage msg subModel
                |> wrapWith (Develop session) GotDevelopMsg

        ( Recv msg, _ ) ->
            let
                _ = Debug.log "Recv" (decodePortMsg msg)
            in
            ( model, Cmd.none )

        ( _, _ ) ->
            ( model, Cmd.none )


-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model =
    let
        _ = Debug.log "subscriptions" model
        pageSubscriptions m =
            case m of
                NotFound _ ->
                    Sub.none

                Home _ subModel ->
                    Sub.map GotHomeMsg (subscriptionsHomePage subModel)

                Develop _ subModel ->
                   Sub.map GotDevelopMsg (subscriptionsDevelopPage subModel)
    in
    Sub.batch
    [ pageSubscriptions model
    , js2elm Recv
    ]

-- VIEW
view : Model -> Browser.Document Msg
view model =
    let
        _ = Debug.log "view" model
        viewPage toMsg { title, body } =
            { title = title, body = List.map (Html.map toMsg) body }
    in
    case model of
        NotFound _ ->
            viewNotFoundPage

        Home _ subModel ->
            viewPage GotHomeMsg (viewHomePage subModel)

        Develop _ subModel ->
            viewPage GotDevelopMsg (viewDevelopPage subModel)

-- NOTFOUND
viewNotFoundPage : { title : String, body : List (Html Msg) }
viewNotFoundPage = 
    { title = "Not Found", body = [ Html.text "Not Found" ] }

-- following codes are implementation of other pages

-- HOME
type alias HomeModel =
    { session : Session
    }

type alias HomeMsg = SubMsg

initHomePage : Session -> ( HomeModel, Cmd HomeMsg )
initHomePage session =
    let
        _ = Debug.log "initHomePage" session
    in
    ( HomeModel session
    , Cmd.none
    )

updateHomePage : HomeMsg -> HomeModel -> ( HomeModel, Cmd HomeMsg )
updateHomePage msg model =
    case msg of
        NoOps ->
            ( model, Cmd.none )
        _ ->
            ( model, Cmd.none )

subscriptionsHomePage : HomeModel -> Sub HomeMsg
subscriptionsHomePage model =
    Sub.none

viewHomePage : HomeModel -> { title : String, body : List (Html HomeMsg) }
viewHomePage model =
    { title = "ignite - Home"
    , body =
        [ text "Home"
        ]
    }


-- DEVELOP

type alias DevelopModel =
    { session : Session
    }

type alias DevelopMsg = SubMsg

initDevelopPage : Session -> ( DevelopModel, Cmd DevelopMsg )
initDevelopPage session =
    ( DevelopModel session
    , Cmd.none
    )

updateDevelopPage : DevelopMsg -> DevelopModel -> ( DevelopModel, Cmd DevelopMsg )
updateDevelopPage msg model =
    case msg of
        NoOps ->
            ( model, Cmd.none )
        Send ->
            ( model, elm2js (encodePortMsg <| PortMsg "elm-message" "hello")
            )

subscriptionsDevelopPage : DevelopModel -> Sub DevelopMsg
subscriptionsDevelopPage model =
    Sub.none

viewDevelopPage : DevelopModel -> { title : String, body : List (Html DevelopMsg) }
viewDevelopPage model =
    { title = "ignite - Develop"
    , body =
        [ h3 []
            [ text "Develop"
            ]
        , button [ onClick Send ] [ text "elm2js message" ]
        ]
    }
