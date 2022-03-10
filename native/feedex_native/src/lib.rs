use rustler::{Encoder, Env, NifResult, Term};
use serde_json::json;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[rustler::nif]
fn parse_rss(env: Env, rss_str: String) -> NifResult<Term> {
    let channel = rss::Channel::read_from(rss_str.as_bytes())
        .map_err(|err| format!("Unable to parse RSS - ({:?})", err));

    let chanel_json = json!(channel);

    let ser = serde_rustler::Serializer::from(env);
    let encoded = serde_transcode::transcode(chanel_json, ser)
        .map_err(|_err| "Unable to encode to erlang terms");

    match encoded {
        Ok(term) => Ok(term),
        Err(error_message) => Ok((atoms::error(), error_message).encode(env)),
    }
}

use atom_syndication::Feed;

#[rustler::nif]
fn parse_atom(env: Env, rss_str: String) -> NifResult<Term> {
    match Feed::read_from(rss_str.as_bytes()) {
        Ok(feed) => {
            let chanel_json = json!(feed);

            let ser = serde_rustler::Serializer::from(env);
            let encoded = serde_transcode::transcode(chanel_json, ser)
                .map_err(|_err| "Unable to encode to erlang terms");
            match encoded {
                Ok(term) => Ok(term),
                Err(error_message) => Ok((atoms::error(), error_message).encode(env)),
            }
        }
        Err(err) => Ok((atoms::error(), err.to_string()).encode(env)),
    }
}

rustler::init!("Elixir.Feedex.Native", [parse_atom, parse_rss]);
