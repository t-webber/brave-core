//! Storage and retrieval for redirect and scriptlet resources.

use std::collections::HashMap;

use base64::{engine::Engine as _, prelude::BASE64_STANDARD};
use once_cell::sync::Lazy;
use regex::Regex;
use thiserror::Error;

use super::{PermissionMask, Resource, ResourceType};

/// Unified resource storage for both redirects and scriptlets.
#[derive(Default)]
pub struct ResourceStorage {
    /// Stores each resource by its canonical name
    resources: HashMap<String, Resource>,
    /// Stores mappings from aliases to their canonical resource names
    aliases: HashMap<String, String>,
}

/// Formats `arg` such that it either is a JSON string, or is safe to insert within a JSON string,
/// depending on `QUOTED`.
///
/// Implementation modified from `json-rust` (MIT license).
/// https://github.com/maciejhirsz/json-rust
#[inline(always)]
fn stringify_arg<const QUOTED: bool>(arg: &str) -> String {
    const QU: u8 = b'"';
    const BS: u8 = b'\\';
    const BB: u8 = b'b';
    const TT: u8 = b't';
    const NN: u8 = b'n';
    const FF: u8 = b'f';
    const RR: u8 = b'r';
    const UU: u8 = b'u';
    const __: u8 = 0;

    // Look up table for characters that need escaping in a product string
    static ESCAPED: [u8; 256] = [
    // 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F
      UU, UU, UU, UU, UU, UU, UU, UU, BB, TT, NN, UU, FF, RR, UU, UU, // 0
      UU, UU, UU, UU, UU, UU, UU, UU, UU, UU, UU, UU, UU, UU, UU, UU, // 1
      __, __, QU, __, __, __, __, __, __, __, __, __, __, __, __, __, // 2
      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, // 3
      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, // 4
      __, __, __, __, __, __, __, __, __, __, __, __, BS, __, __, __, // 5
      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, // 6
      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, // 7
      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, // 8
      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, // 9
      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, // A
      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, // B
      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, // C
      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, // D
      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, // E
      __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, __, // F
    ];

    #[inline(never)]
    fn write_string_complex(output: &mut Vec<u8>, string: &str, mut start: usize) {
        output.extend_from_slice(&string.as_bytes()[ .. start]);

        for (index, ch) in string.bytes().enumerate().skip(start) {
            let escape = ESCAPED[ch as usize];
            if escape > 0 {
                output.extend_from_slice(&string.as_bytes()[start .. index]);
                output.extend_from_slice(&[b'\\', escape]);
                start = index + 1;
            }
            if escape == b'u' {
                output.extend_from_slice(format!("{:04x}", ch).as_bytes());
            }
        }
        output.extend_from_slice(&string.as_bytes()[start ..]);
    }

    let mut output = Vec::with_capacity(arg.as_bytes().len() + 2);
    if QUOTED {
        output.push(b'"');
    }

    'process: {
        for (index, ch) in arg.bytes().enumerate() {
            if ESCAPED[ch as usize] > 0 {
                write_string_complex(&mut output, arg, index);
                break 'process;
            }
        }

        output.extend_from_slice(arg.as_bytes());
    }

    if QUOTED {
        output.push(b'"');
    }

    // unwrap safety: input is always valid UTF8; output processing only replaces some ASCII
    // characters with other valid ones
    return String::from_utf8(output).unwrap();
}

/// Gets the function name from a JS function definition
fn extract_function_name(fn_def: &str) -> Option<&str> {
    // This is not bulletproof, but should be robust against most issues.
    const FUNCTION_NAME_RE: Lazy<Regex> = Lazy::new(|| {
        Regex::new(r#"^function\s+([^\(\)\{\}\s]+)\s*\("#).unwrap()
    });

    FUNCTION_NAME_RE.captures(&fn_def).map(|captures| {
        // capture 1 is always present in the above regex if any match was made
        captures.get(1).unwrap().as_str()
    })
}

impl ResourceStorage {
    /// Convenience constructor that allows building storage for many resources at once. Errors are
    /// silently consumed.
    pub fn from_resources(resources: impl IntoIterator<Item=Resource>) -> Self {
        let mut self_ = Self::default();

        resources.into_iter().for_each(|resource| {
            self_
                .add_resource(resource)
                .unwrap_or_else(|_e| {
                    #[cfg(test)]
                    eprintln!("Failed to add resource: {:?}", _e)
                })
        });

        self_
    }

    /// Adds a resource to storage so that it can be retrieved later.
    pub fn add_resource(&mut self, resource: Resource) -> Result<(), AddResourceError> {
        if let ResourceType::Mime(content_type) = &resource.kind {
            if !resource.dependencies.is_empty() && !content_type.supports_dependencies() {
                return Err(AddResourceError::ContentTypeDoesNotSupportDependencies);
            }

            // Ensure the resource contents are valid base64 (and utf8 if applicable)
            let decoded = BASE64_STANDARD.decode(&resource.content)?;
            if content_type.is_textual() {
                let _ = String::from_utf8(decoded)?;
            }
        }

        for ident in std::iter::once(&resource.name).chain(resource.aliases.iter()) {
            if self.resources.contains_key(ident) || self.aliases.contains_key(ident) {
                return Err(AddResourceError::NameAlreadyAdded);
            }
        }

        resource.aliases.iter().for_each(|alias| {
            self.aliases.insert(alias.clone(), resource.name.clone());
        });
        self.resources.insert(resource.name.clone(), resource);

        Ok(())
    }

    /// Given the contents of the `+js(...)` parts of multiple filters, return a script string
    /// appropriate for injection in a page.
    pub fn get_scriptlet_resources<'a>(&self, script_injections: impl IntoIterator<Item = (&'a str, PermissionMask)>) -> String {
        let mut deps = vec![];
        let mut invokations = String::new();

        script_injections.into_iter().for_each(|(s, mask)| {
            if let Ok(invokation) = self.get_scriptlet_resource(s, mask, &mut deps) {
                invokations += "try {\n";
                invokations += &invokation;
                invokations += "\n} catch ( e ) { }\n";
            }
        });

        let mut result = String::new();

        for dep in deps.iter() {
            if let Ok(decoded) = BASE64_STANDARD.decode(&dep.content) {
                if let Ok(dep) = core::str::from_utf8(&decoded) {
                    result += dep;
                    result += "\n";
                }
            }
        }

        result += &invokations;

        result
    }

    /// Add all dependencies of `new_dep` to `prev_deps`, recursively and uniquely. If the given
    /// permission is insufficient for any dependency, this will return an `Error`.
    ///
    /// Note that no ordering is guaranteed; function definitions in JS can appear after they are
    /// used.
    fn recursive_dependencies<'a: 'b, 'b>(&'a self, new_dep: &str, prev_deps: &mut Vec<&'b Resource>, filter_permission: PermissionMask) -> Result<(), ScriptletResourceError> {
        if prev_deps.iter().find(|dep| dep.name == new_dep).is_some() {
            return Ok(());
        }

        let resource = self.get_permissioned_resource(new_dep, filter_permission)?;

        prev_deps.push(resource);

        for dep in resource.dependencies.iter() {
            self.recursive_dependencies(dep, prev_deps, filter_permission)?;
        }

        Ok(())
    }

    /// Given the contents of a single `+js(...)` filter part, return a scriptlet string
    /// appropriate for injection in a page.
    fn get_scriptlet_resource<'a: 'b, 'b>(&'a self, scriptlet_args: &str, filter_permission: PermissionMask, required_deps: &mut Vec<&'b Resource>) -> Result<String, ScriptletResourceError> {
        // `unwrap` is safe because these are guaranteed valid at filter parsing.
        let scriptlet_args = parse_scriptlet_args(scriptlet_args).unwrap();

        if scriptlet_args.is_empty() {
            return Err(ScriptletResourceError::MissingScriptletName);
        }

        let scriptlet_name = with_js_extension(scriptlet_args[0].as_ref());

        let args = &scriptlet_args[1..];
        if args.len() == 1 && args[0].starts_with('{') && args[0].ends_with('}') {
            return Err(ScriptletResourceError::ScriptletArgObjectSyntaxUnsupported);
        }

        let resource = self.get_permissioned_resource(&scriptlet_name, filter_permission)?;

        if !resource.kind.supports_scriptlet_injection() {
            return Err(ScriptletResourceError::ContentTypeNotInjectable);
        }

        for dep in resource.dependencies.iter() {
            self.recursive_dependencies(dep, required_deps, filter_permission)?;
        };

        let template = String::from_utf8(BASE64_STANDARD.decode(&resource.content)?)?;

        if let Some(function_name) = extract_function_name(&template) {
            // newer function-style resource: pass args using function call syntax

            // add the scriptlet itself as a dependency and invoke via function name
            if required_deps.iter().find(|dep| dep.name == resource.name).is_none() {
                required_deps.push(resource);
            }

            use itertools::Itertools as _;
            Ok(format!("{}({})", function_name, args.iter().map(|arg| stringify_arg::<true>(arg)).join(", ")))
        } else {
            // older template-style resource: replace first instances with args
            Ok(patch_template_scriptlet(template, args.iter().map(|arg| stringify_arg::<false>(arg))))
        }
    }

    /// Get a data-URL formatted resource appropriate for a `$redirect` response.
    pub fn get_redirect_resource(&self, resource_ident: &str) -> Option<String> {
        let resource = self.get_internal_resource(resource_ident);

        resource.and_then(|resource| {
            if !resource.permission.is_default() {
                return None;
            }
            if !resource.kind.supports_redirect() {
                return None;
            }
            if let ResourceType::Mime(mime) = &resource.kind {
                Some(format!("data:{};base64,{}", mime, &resource.content))
            } else {
                None
            }
        })
    }

    /// Gets the resource associated with `resource_ident`, respecting aliases if necessary.
    fn get_internal_resource(&self, resource_ident: &str) -> Option<&Resource> {
        let resource = if let Some(resource) = self.resources.get(resource_ident) {
            Some(resource)
        } else if let Some(canonical_name) = self.aliases.get(resource_ident) {
            self.resources.get(canonical_name)
        } else {
            None
        };

        resource
    }

    fn get_permissioned_resource(&self, scriptlet_name: &str, filter_permission: PermissionMask) -> Result<&Resource, ScriptletResourceError> {
        let resource = self
            .get_internal_resource(&scriptlet_name)
            .ok_or(ScriptletResourceError::NoMatchingScriptlet)?;

        if !resource.permission.is_injectable_by(filter_permission) {
            return Err(ScriptletResourceError::InsufficientPermissions);
        }

        Ok(resource)
    }
}

/// Describes failure cases when preparing [`Resource`]s to be used for adblocking.
#[derive(Debug, Error, PartialEq)]
pub enum AddResourceError {
    #[error("invalid base64 content")]
    InvalidBase64Content,
    #[error("invalid utf-8 content")]
    InvalidUtf8Content,
    #[error("resource name already added")]
    NameAlreadyAdded,
    #[error("resource content type does not support dependencies")]
    ContentTypeDoesNotSupportDependencies,
}

impl From<base64::DecodeError> for AddResourceError {
    fn from(_: base64::DecodeError) -> Self {
        AddResourceError::InvalidBase64Content
    }
}

impl From<std::string::FromUtf8Error> for AddResourceError {
    fn from(_: std::string::FromUtf8Error) -> Self {
        AddResourceError::InvalidUtf8Content
    }
}

/// Describes failure cases when attempting to retrieve a resource for scriptlet injection.
#[derive(Debug, Error, PartialEq)]
pub enum ScriptletResourceError {
    #[error("no scriptlet has the provided name")]
    NoMatchingScriptlet,
    #[error("no scriptlet name was provided")]
    MissingScriptletName,
    #[error("object syntax for scriptlet arguments is unsupported")]
    ScriptletArgObjectSyntaxUnsupported,
    #[error("scriptlet content was corrupted")]
    CorruptScriptletContent,
    #[error("resource content type cannot be used for a scriptlet injection")]
    ContentTypeNotInjectable,
    #[error("filter rule is not authorized to inject the intended scriptlet")]
    InsufficientPermissions,
}

impl From<base64::DecodeError> for ScriptletResourceError {
    fn from(_: base64::DecodeError) -> Self {
        Self::CorruptScriptletContent
    }
}

impl From<std::string::FromUtf8Error> for ScriptletResourceError {
    fn from(_: std::string::FromUtf8Error) -> Self {
        Self::CorruptScriptletContent
    }
}

static TEMPLATE_ARGUMENT_RE: [Lazy<Regex>; 9] = [
    Lazy::new(|| template_argument_regex(1)),
    Lazy::new(|| template_argument_regex(2)),
    Lazy::new(|| template_argument_regex(3)),
    Lazy::new(|| template_argument_regex(4)),
    Lazy::new(|| template_argument_regex(5)),
    Lazy::new(|| template_argument_regex(6)),
    Lazy::new(|| template_argument_regex(7)),
    Lazy::new(|| template_argument_regex(8)),
    Lazy::new(|| template_argument_regex(9)),
];

fn template_argument_regex(i: usize) -> Regex {
    Regex::new(&format!(r"\{{\{{{}\}}\}}", i)).unwrap()
}

/// Omit the 0th element of `args` (the scriptlet name) when calling this method.
fn patch_template_scriptlet(mut template: String, args: impl IntoIterator<Item = impl AsRef<str>>) -> String {
    // `regex` treats `$` as a special character. Instead, `$$` is interpreted as a literal `$`
    // character.
    args.into_iter().take(TEMPLATE_ARGUMENT_RE.len()).enumerate().for_each(|(i, arg)| {
        template = TEMPLATE_ARGUMENT_RE[i]
            .replace(&template, arg.as_ref().replace('$', "$$"))
            .to_string();
    });
    template
}

/// Scriptlet injections must be JS resources. However, the `.js` extension may need to be added as
/// a canonicalization step, since it can be omitted in filter rules.
fn with_js_extension(scriptlet_name: &str) -> String {
    if scriptlet_name.ends_with(".js") {
        scriptlet_name.to_string()
    } else {
        format!("{}.js", scriptlet_name)
    }
}

/// Returns the index of the next unescaped separator, as well as a boolean indicating whether or
/// not the string must be postprocessed to normalize any separators along the way.
fn index_next_unescaped_separator(s: &str, separator: char) -> (Option<usize>, bool) {
    assert!(separator != '\\');
    let mut new_arg_end = 0;
    let mut needs_transform = false;
    // guaranteed to terminate:
    // - loop only proceeds if there is an odd number of escape characters
    // - new_arg_end increases by at least 1 in that case
    // - s has finite length
    while new_arg_end < s.len() {
        let rest = &s[new_arg_end..];

        if let Some(i) = rest.find(separator) {
            // check how many escape characters there are before the matched separator
            let mut trailing_escapes = 0;
            while trailing_escapes < i && rest[..i - trailing_escapes].ends_with('\\') {
                trailing_escapes += 1;
            }
            if trailing_escapes % 2 == 0 {
                // even number; all escape characters are literal backslashes
                new_arg_end += i;
                break;
            } else {
                // odd number; the last escape character is escaping this separator
                new_arg_end += i + 1;
                needs_transform = true;
                continue;
            }
        } else {
            // no match
            return (None, needs_transform)
        }
    }
    // don't index beyond the end of the string
    let new_arg_end = if new_arg_end >= s.len() {
        None
    } else {
        Some(new_arg_end)
    };
    (new_arg_end, needs_transform)
}

/// Replaces escaped instances of `separator` in `arg` with unescaped characters.
fn normalize_arg(arg: &str, separator: char) -> String {
    assert!(separator != '\\');

    let mut output = String::with_capacity(arg.len());
    let mut escaped = false;
    for i in arg.chars() {
        if i == '\\' {
            if escaped {
                escaped = false;
                output += "\\\\";
            } else {
                escaped = true;
            }
            continue;
        }

        if escaped {
            if i != separator {
                output.push('\\');
            }
            escaped = false;
        }

        output.push(i);
    }

    output
}

/// Parses the inner contents of a `+js(...)` operator of a cosmetic filter.
///
/// Returns `None` if the contents are malformed.
pub(crate) fn parse_scriptlet_args(mut args: &str) -> Option<Vec<String>> {
    let mut args_vec = vec![];
    if args.trim().is_empty() {
        return Some(args_vec);
    }

    // guaranteed to terminate:
    // - each branch of the `match` consumes at least 1 character from the beginning of `args`
    // - loop exits if `args` is empty
    loop {
        // n.b. `args.trim_start()` leaves an empty string if it's only whitespace
        if let Some(i) = args.find(|c: char| !c.is_whitespace()) {
            args = &args[i..];
        }

        let (arg, needs_transform);

        match args.chars().next() {
            Some(qc) if qc == '"' || qc == '\'' || qc == '`' => {
                args = &args[1..];
                let i;
                (i, needs_transform) = index_next_unescaped_separator(args, qc);
                if let Some(i) = i {
                    arg = &args[..i];
                    args = &args[i+1..];
                    // consume whitespace following the quote
                    if let Some(i) = args.find(|c: char| !c.is_whitespace()) {
                        args = &args[i..];
                    }
                    // consume comma separator
                    if args.starts_with(',') {
                        args = &args[1..];
                    } else if !args.is_empty() {
                        // uBO pushes everything up to the next comma without escapes, but it's
                        // very weird and probably not what the filter list author intended.
                        // Treating it as an error for now.
                        return None;
                    }
                } else {
                    // uBO pushes the entire argument, including the unmatched quote. Again, weird
                    // and probably not intended.
                    return None;
                }
            }
            Some(_) => {
                let i;
                (i, needs_transform) = index_next_unescaped_separator(args, ',');
                arg = args[..i.unwrap_or(args.len())].trim_end();
                args = &args[i.map(|i| i + 1).unwrap_or(args.len())..];
            }
            None => {
                // `args` is empty
                break;
            }
        }

        let arg = if needs_transform {
            normalize_arg(arg, ',')
        } else {
            arg.to_string()
        };
        args_vec.push(arg);
    }

    Some(args_vec)
}

#[cfg(test)]
mod extract_function_name_tests {
    use super::extract_function_name;

    #[test]
    fn test_extract_function_name() {
        assert_eq!(extract_function_name("function test() {}"), Some("test"));
        assert_eq!(extract_function_name("function $() {}"), Some("$"));
        assert_eq!(extract_function_name("function _() {}"), Some("_"));
        assert_eq!(extract_function_name("function ಠ_ಠ() {}"), Some("ಠ_ಠ"));
        assert_eq!(extract_function_name("function\ntest\n(\n)\n{\n}"), Some("test"));
        assert_eq!(extract_function_name("function\ttest\t(\t)\t{\t}"), Some("test"));
        assert_eq!(extract_function_name("function test() { (function inner() {})() }"), Some("test"));
        assert_eq!(extract_function_name("let e = function test() { (function inner() {})() }"), None);
        assert_eq!(extract_function_name("function () { (function inner() {})() }"), None);
    }
}

#[cfg(test)]
mod arg_parsing_util_tests {
    use super::*;

    #[test]
    fn test_index_next_unescaped_separator() {
        assert_eq!(index_next_unescaped_separator(r#"``"#, '`'), (Some(0), false));
        assert_eq!(index_next_unescaped_separator(r#"\``"#, '`'), (Some(2), true));
        assert_eq!(index_next_unescaped_separator(r#"\\``"#, '`'), (Some(2), false));
        assert_eq!(index_next_unescaped_separator(r#"\\\``"#, '`'), (Some(4), true));
        assert_eq!(index_next_unescaped_separator(r#"\\\\``"#, '`'), (Some(4), false));
        assert_eq!(index_next_unescaped_separator(r#"\`\\\``"#, '`'), (Some(6), true));
        assert_eq!(index_next_unescaped_separator(r#"\\\`\``"#, '`'), (Some(6), true));
        assert_eq!(index_next_unescaped_separator(r#"\\\`\\``"#, '`'), (Some(6), true));

        assert_eq!(index_next_unescaped_separator(r#"\,test\,"#, ','), (None, true))
    }

    #[test]
    fn test_normalize_arg() {
        assert_eq!(normalize_arg(r#"\`"#, '`'), r#"`"#);
        assert_eq!(normalize_arg(r#"\\\`"#, '`'), r#"\\`"#);
        assert_eq!(normalize_arg(r#"\`\\\`"#, '`'), r#"`\\`"#);
        assert_eq!(normalize_arg(r#"\\\`\`"#, '`'), r#"\\``"#);
        assert_eq!(normalize_arg(r#"\\\`\\`"#, '`'), r#"\\`\\`"#);
    }
}

#[cfg(test)]
mod redirect_storage_tests {
    use super::*;
    use crate::resources::MimeType;

    #[test]
    fn get_resource_by_name() {
        let mut storage = ResourceStorage::default();
        storage
            .add_resource(
                Resource::simple("name.js", MimeType::ApplicationJavascript, "resource data"),
            )
            .unwrap();

        assert_eq!(
            storage.get_redirect_resource("name.js"),
            Some(format!("data:application/javascript;base64,{}", BASE64_STANDARD.encode("resource data"))),
        );
    }

    #[test]
    fn get_resource_by_alias() {
        let mut storage = ResourceStorage::default();
        let mut r = Resource::simple("name.js", MimeType::ApplicationJavascript, "resource data");
        r.aliases.push("alias.js".to_string());
        storage
            .add_resource(r)
            .unwrap();

        assert_eq!(
            storage.get_redirect_resource("alias.js"),
            Some(format!("data:application/javascript;base64,{}", BASE64_STANDARD.encode("resource data"))),
        );
    }

    #[test]
    fn permissions() {
        let mut storage = ResourceStorage::default();
        let mut r = Resource::simple("name.js", MimeType::ApplicationJavascript, "resource data");
        r.aliases.push("alias.js".to_string());
        r.permission = PermissionMask::from_bits(0b00000001);
        storage
            .add_resource(r)
            .unwrap();

        assert_eq!(
            storage.get_redirect_resource("name.js"),
            None,
        );
        assert_eq!(
            storage.get_redirect_resource("alias.js"),
            None,
        );
    }
}

#[cfg(test)]
mod scriptlet_storage_tests {
    use super::*;
    use crate::resources::MimeType;

    #[test]
    fn parse_argslist() {
        let args = parse_scriptlet_args("scriptlet, hello world, foobar").unwrap();
        assert_eq!(args, vec!["scriptlet", "hello world", "foobar"]);
    }

    #[test]
    fn parse_argslist_noargs() {
        let args = parse_scriptlet_args("scriptlet").unwrap();
        assert_eq!(args, vec!["scriptlet"]);
    }

    #[test]
    fn parse_argslist_empty() {
        let args = parse_scriptlet_args("").unwrap();
        assert!(args.is_empty());
    }

    #[test]
    fn parse_argslist_commas() {
        let args = parse_scriptlet_args("scriptletname, one\\, two\\, three, four").unwrap();
        assert_eq!(args, vec!["scriptletname", "one, two, three", "four"]);
    }

    #[test]
    fn parse_argslist_badchars() {
        let args = parse_scriptlet_args(
            r##"scriptlet, "; window.location.href = bad.com; , '; alert("you're\, hacked");    ,    \u\r\l(bad.com) "##,
        );
        assert_eq!(args, None);
    }

    #[test]
    fn parse_argslist_quoted() {
        let args = parse_scriptlet_args(r#"debug-scriptlet, 'test', '"test"', "test", "'test'", `test`, '`test`'"#).unwrap();
        assert_eq!(
            args,
            vec![
                r#"debug-scriptlet"#,
                r#"test"#,
                r#""test""#,
                r#"test"#,
                r#"'test'"#,
                r#"test"#,
                r#"`test`"#,
            ],
        );
        let args = parse_scriptlet_args(r#"debug-scriptlet, 'test,test', '', "", ' ', ' test '"#).unwrap();
        assert_eq!(
            args,
            vec![
                r#"debug-scriptlet"#,
                r#"test,test"#,
                r#""#,
                r#""#,
                r#" "#,
                r#" test "#,
            ],
        );
        let args = parse_scriptlet_args(r#"debug-scriptlet, test\,test, test\test, "test\test", 'test\test', "#).unwrap();
        assert_eq!(
            args,
            vec![
                r#"debug-scriptlet"#,
                r#"test,test"#,
                r#"test\test"#,
                r#"test\test"#,
                r#"test\test"#,
                r#""#,
            ],
        );
        let args = parse_scriptlet_args(r#"debug-scriptlet, "test"#);
        assert_eq!(args, None);
        let args = parse_scriptlet_args(r#"debug-scriptlet, 'test'"test""#);
        assert_eq!(args, None);
    }

    #[test]
    fn parse_argslist_trailing_escaped_comma() {
        let args = parse_scriptlet_args(r#"remove-node-text, script, \,mr=function(r\,"#).unwrap();
        assert_eq!(args, vec!["remove-node-text", "script", ",mr=function(r,"]);
    }

    #[test]
    fn get_patched_scriptlets() {
        let resources = ResourceStorage::from_resources([
            Resource {
                name: "greet.js".to_string(),
                aliases: vec![],
                kind: ResourceType::Template,
                content: BASE64_STANDARD.encode("console.log('Hello {{1}}, my name is {{2}}')"),
                dependencies: vec![],
                permission: Default::default(),
            },
            Resource {
                name: "alert.js".to_owned(),
                aliases: vec![],
                kind: ResourceType::Template,
                content: BASE64_STANDARD.encode("alert('{{1}}')"),
                dependencies: vec![],
                permission: Default::default(),
            },
            Resource {
                name: "blocktimer.js".to_owned(),
                aliases: vec![],
                kind: ResourceType::Template,
                content: BASE64_STANDARD.encode("setTimeout(blockAds, {{1}})"),
                dependencies: vec![],
                permission: Default::default(),
            },
            Resource {
                name: "null.js".to_owned(),
                aliases: vec![],
                kind: ResourceType::Template,
                content: BASE64_STANDARD.encode("(()=>{})()"),
                dependencies: vec![],
                permission: Default::default(),
            },
            Resource {
                name: "set-local-storage-item.js".to_owned(),
                aliases: vec![],
                kind: ResourceType::Template,
                content: BASE64_STANDARD
                    .encode(r#"{{1}} that dollar signs in {{2}} are untouched"#),
                dependencies: vec![],
                permission: Default::default(),
            },
        ]);

        assert_eq!(
            resources.get_scriptlet_resources([("greet, world, adblock-rust", Default::default())]),
            "try {\nconsole.log('Hello world, my name is adblock-rust')\n} catch ( e ) { }\n",
        );
        assert_eq!(
            resources.get_scriptlet_resources([("alert, All systems are go!! ", Default::default())]),
            "try {\nalert('All systems are go!!')\n} catch ( e ) { }\n",
        );
        assert_eq!(
            resources.get_scriptlet_resources([("alert, Uh oh\\, check the logs...", Default::default())]),
            "try {\nalert('Uh oh, check the logs...')\n} catch ( e ) { }\n",
        );
        assert_eq!(
            resources.get_scriptlet_resources([(r#"alert, this has "quotes""#, Default::default())]),
            "try {\nalert('this has \\\"quotes\\\"')\n} catch ( e ) { }\n",
        );
        assert_eq!(
            resources.get_scriptlet_resources([("blocktimer, 3000", Default::default())]),
            "try {\nsetTimeout(blockAds, 3000)\n} catch ( e ) { }\n",
        );
        assert_eq!(
            resources.get_scriptlet_resources([("null", Default::default())]),
            "try {\n(()=>{})()\n} catch ( e ) { }\n"
        );
        assert_eq!(
            resources.get_scriptlet_resources([("null, null", Default::default())]),
            "try {\n(()=>{})()\n} catch ( e ) { }\n",
        );
        assert_eq!(
            resources.get_scriptlet_resources([("greet, everybody", Default::default())]),
            "try {\nconsole.log('Hello everybody, my name is {{2}}')\n} catch ( e ) { }\n",
        );

        assert_eq!(
            resources.get_scriptlet_resource("unit-testing", Default::default(), &mut vec![]),
            Err(ScriptletResourceError::NoMatchingScriptlet),
        );
        assert_eq!(
            resources.get_scriptlet_resource("", Default::default(), &mut vec![]),
            Err(ScriptletResourceError::MissingScriptletName),
        );

        assert_eq!(
            resources.get_scriptlet_resources([("set-local-storage-item, Test, $remove$", Default::default())]),
            "try {\nTest that dollar signs in $remove$ are untouched\n} catch ( e ) { }\n",
        );
    }

    #[test]
    fn parse_template_file_format() {
        let resources = ResourceStorage::from_resources([
            Resource {
                name: "abort-current-inline-script.js".into(),
                aliases: vec!["acis.js".into()],
                kind: ResourceType::Mime(MimeType::ApplicationJavascript),
                content: BASE64_STANDARD.encode("(function() {alert(\"hi\");})();"),
                dependencies: vec![],
                permission: Default::default(),
            },
            Resource {
                name: "abort-on-property-read.js".into(),
                aliases: vec!["aopr.js".into()],
                kind: ResourceType::Template,
                content: BASE64_STANDARD
                    .encode("(function() {confirm(\"Do you want to {{1}}?\");})();"),
                dependencies: vec![],
                permission: Default::default(),
            },
            Resource {
                name: "googletagservices_gpt.js".into(),
                aliases: vec!["googletagservices.com/gpt.js".into(), "googletagservices-gpt".into()],
                kind: ResourceType::Template,
                content: BASE64_STANDARD
                    .encode("function gpt(a1 = '', a2 = '') {console.log(a1, a2)}"),
                dependencies: vec![],
                permission: Default::default(),
            },
        ]);

        assert_eq!(
            resources.get_scriptlet_resources([("aopr, code", Default::default())]),
            "try {\n(function() {confirm(\"Do you want to code?\");})();\n} catch ( e ) { }\n",
        );

        assert_eq!(
            resources.get_scriptlet_resources([("abort-on-property-read, write tests", Default::default())]),
            "try {\n(function() {confirm(\"Do you want to write tests?\");})();\n} catch ( e ) { }\n",
        );

        assert_eq!(
            resources.get_scriptlet_resources([("abort-on-property-read.js, block advertisements", Default::default())]),
            "try {\n(function() {confirm(\"Do you want to block advertisements?\");})();\n} catch ( e ) { }\n",
        );

        assert_eq!(
            resources.get_scriptlet_resources([("acis", Default::default())]),
            "try {\n(function() {alert(\"hi\");})();\n} catch ( e ) { }\n",
        );

        assert_eq!(
            resources.get_scriptlet_resources([("acis.js", Default::default())]),
            "try {\n(function() {alert(\"hi\");})();\n} catch ( e ) { }\n",
        );

        assert_eq!(
            resources.get_scriptlet_resources([("googletagservices_gpt.js", Default::default())]),
            "function gpt(a1 = '', a2 = '') {console.log(a1, a2)}\ntry {\ngpt()\n} catch ( e ) { }\n",
        );

        assert_eq!(
            resources.get_scriptlet_resources([("googletagservices_gpt, test1", Default::default())]),
            "function gpt(a1 = '', a2 = '') {console.log(a1, a2)}\ntry {\ngpt(\"test1\")\n} catch ( e ) { }\n",
        );

        assert_eq!(
            resources.get_scriptlet_resources([("googletagservices.com/gpt, test1, test2", Default::default())]),
            "function gpt(a1 = '', a2 = '') {console.log(a1, a2)}\ntry {\ngpt(\"test1\", \"test2\")\n} catch ( e ) { }\n",
        );

        assert_eq!(
            resources.get_scriptlet_resource(r#"googletagservices.com/gpt.js, t"es't1, $te\st2$"#, Default::default(), &mut vec![]),
            Ok(r#"gpt("t\"es't1", "$te\\st2$")"#.to_owned()),
        );

        // The alias does not have a `.js` extension, so it cannot be used for a scriptlet
        // injection (only as a redirect resource).
        assert_eq!(
            resources.get_scriptlet_resource(r#"googletagservices-gpt, t"es't1, te\st2"#, Default::default(), &mut vec![]),
            Err(ScriptletResourceError::NoMatchingScriptlet),
        );

        // Object-style injection
        assert_eq!(
            resources.get_scriptlet_resource(r#"googletagservices.com/gpt, { "test": true }"#, Default::default(), &mut vec![]),
            Err(ScriptletResourceError::ScriptletArgObjectSyntaxUnsupported),
        );
    }

    /// Currently, only 9 template arguments are supported - but reaching that limit should not
    /// cause a panic.
    #[test]
    fn patch_argslist_many_args() {
        let resources = ResourceStorage::from_resources([
            Resource {
                name: "abort-current-script.js".into(),
                aliases: vec!["acs.js".into()],
                kind: ResourceType::Mime(MimeType::ApplicationJavascript),
                content: BASE64_STANDARD.encode(
                    "{{1}} {{2}} {{3}} {{4}} {{5}} {{6}} {{7}} {{8}} {{9}} {{10}} {{11}} {{12}}",
                ),
                dependencies: vec![],
                permission: Default::default(),
            },
        ]);

        let args = parse_scriptlet_args("acs, this, probably, is, going, to, break, brave, and, crash, it, instead, of, ignoring, it").unwrap();
        assert_eq!(args, vec!["acs", "this", "probably", "is", "going", "to", "break", "brave", "and", "crash", "it", "instead", "of", "ignoring", "it"]);

        assert_eq!(
            resources.get_scriptlet_resources([("acs, this, probably, is, going, to, break, brave, and, crash, it, instead, of, ignoring, it", Default::default())]),
            "try {\nthis probably is going to break brave and crash {{10}} {{11}} {{12}}\n} catch ( e ) { }\n",
        );
    }

    #[test]
    fn permissions() {
        const PERM01: PermissionMask = PermissionMask::from_bits(0b00000001);
        const PERM10: PermissionMask = PermissionMask::from_bits(0b00000010);
        const PERM11: PermissionMask = PermissionMask::from_bits(0b00000011);
        let resources = ResourceStorage::from_resources([
            Resource::simple("default-perms.js", MimeType::ApplicationJavascript, "default-perms"),
            Resource {
                name: "perm0.js".into(),
                aliases: vec!["0.js".to_string()],
                kind: ResourceType::Mime(MimeType::ApplicationJavascript),
                content: BASE64_STANDARD.encode("perm0"),
                dependencies: vec![],
                permission: PERM01,
            },
            Resource {
                name: "perm1.js".into(),
                aliases: vec!["1.js".to_string()],
                kind: ResourceType::Mime(MimeType::ApplicationJavascript),
                content: BASE64_STANDARD.encode("perm1"),
                dependencies: vec![],
                permission: PERM10,
            },
            Resource {
                name: "perm10.js".into(),
                aliases: vec!["10.js".to_string()],
                kind: ResourceType::Mime(MimeType::ApplicationJavascript),
                content: BASE64_STANDARD.encode("perm10"),
                dependencies: vec![],
                permission: PERM11,
            },
        ]);

        fn test_perm(resources: &ResourceStorage, perm: PermissionMask, expect_ok: &[&str], expect_fail: &[&str]) {
            for ident in expect_ok {
                if ident.len() > 2 {
                    assert_eq!(
                        resources.get_scriptlet_resources([(*ident, perm)]),
                        format!("try {{\n{}\n}} catch ( e ) {{ }}\n", ident),
                    );
                } else {
                    assert_eq!(
                        resources.get_scriptlet_resources([(*ident, perm)]),
                        format!("try {{\nperm{}\n}} catch ( e ) {{ }}\n", ident),
                    );
                }
            }

            for ident in expect_fail {
                assert_eq!(
                    resources.get_scriptlet_resource(ident, perm, &mut vec![]),
                    Err(ScriptletResourceError::InsufficientPermissions),
                );
            }
        }

        test_perm(&resources, Default::default(), &["default-perms"], &["perm0", "perm1", "perm10", "0", "1", "10"]);
        test_perm(&resources, PERM01, &["default-perms", "perm0", "0"], &["perm1", "perm10", "1", "10"]);
        test_perm(&resources, PERM10, &["default-perms", "perm1", "1"], &["perm0", "perm10", "0", "10"]);
        test_perm(&resources, PERM11, &["default-perms", "perm0", "perm1", "perm10", "0", "1", "10"], &[]);
    }

    #[test]
    fn dependencies() {
        const PERM01: PermissionMask = PermissionMask::from_bits(0b00000001);
        let resources = ResourceStorage::from_resources([
            Resource::simple("simple.fn", MimeType::FnJavascript, "simple"),
            Resource {
                name: "permissioned.fn".into(),
                aliases: vec![],
                kind: ResourceType::Mime(MimeType::FnJavascript),
                content: BASE64_STANDARD.encode("permissioned"),
                dependencies: vec!["a.fn".to_string(), "common.fn".to_string()],
                permission: PERM01,
            },
            Resource {
                name: "a.fn".into(),
                aliases: vec![],
                kind: ResourceType::Mime(MimeType::FnJavascript),
                content: BASE64_STANDARD.encode("a"),
                dependencies: vec!["common.fn".to_string()],
                permission: Default::default(),
            },
            Resource {
                name: "b.fn".into(),
                aliases: vec![],
                kind: ResourceType::Mime(MimeType::FnJavascript),
                content: BASE64_STANDARD.encode("b"),
                dependencies: vec!["common.fn".to_string()],
                permission: Default::default(),
            },
            Resource {
                name: "common.fn".into(),
                aliases: vec![],
                kind: ResourceType::Mime(MimeType::FnJavascript),
                content: BASE64_STANDARD.encode("common"),
                dependencies: vec![],
                permission: Default::default(),
            },
            Resource {
                name: "test.js".into(),
                aliases: vec![],
                kind: ResourceType::Mime(MimeType::ApplicationJavascript),
                content: BASE64_STANDARD.encode("function test() {}"),
                dependencies: vec!["permissioned.fn".to_string(), "a.fn".to_string(), "b.fn".to_string(), "common.fn".to_string()],
                permission: Default::default(),
            },
            Resource {
                name: "deploop1.fn".into(),
                aliases: vec![],
                kind: ResourceType::Mime(MimeType::FnJavascript),
                content: BASE64_STANDARD.encode("deploop1"),
                dependencies: vec!["deploop1.fn".to_string()],
                permission: Default::default(),
            },
            Resource {
                name: "deploop2a.fn".into(),
                aliases: vec![],
                kind: ResourceType::Mime(MimeType::FnJavascript),
                content: BASE64_STANDARD.encode("deploop2a"),
                dependencies: vec!["deploop2b.fn".to_string()],
                permission: Default::default(),
            },
            Resource {
                name: "deploop2b.fn".into(),
                aliases: vec![],
                kind: ResourceType::Mime(MimeType::FnJavascript),
                content: BASE64_STANDARD.encode("deploop2b"),
                dependencies: vec!["deploop2a.fn".to_string()],
                permission: Default::default(),
            },
            Resource {
                name: "test-wrapper.js".into(),
                aliases: vec![],
                kind: ResourceType::Mime(MimeType::ApplicationJavascript),
                content: BASE64_STANDARD.encode("function testWrapper() { test(arguments) }"),
                dependencies: vec!["test.js".to_string()],
                permission: Default::default(),
            },
            Resource {
                name: "shared.js".into(),
                aliases: vec![],
                kind: ResourceType::Mime(MimeType::ApplicationJavascript),
                content: BASE64_STANDARD.encode("function shared() { }"),
                dependencies: vec!["a.fn".to_string(), "b.fn".to_string()],
                permission: Default::default(),
            },
        ]);

        {
            let mut deps = vec![];
            assert_eq!(resources.recursive_dependencies("common.fn", &mut deps, Default::default()), Ok(()));
            assert_eq!(deps.iter().map(|dep| dep.name.to_string()).collect::<Vec<_>>(), vec!["common.fn"]);
        }

        {
            let mut deps = vec![];
            assert_eq!(resources.recursive_dependencies("a.fn", &mut deps, Default::default()), Ok(()));
            assert_eq!(deps.iter().map(|dep| dep.name.to_string()).collect::<Vec<_>>(), vec!["a.fn", "common.fn"]);
        }

        {
            let mut deps = vec![];
            assert_eq!(resources.recursive_dependencies("b.fn", &mut deps, Default::default()), Ok(()));
            assert_eq!(deps.iter().map(|dep| dep.name.to_string()).collect::<Vec<_>>(), vec!["b.fn", "common.fn"]);
        }

        {
            let mut deps = vec![];
            assert_eq!(resources.recursive_dependencies("permissioned.fn", &mut deps, Default::default()), Err(ScriptletResourceError::InsufficientPermissions));
        }
        {
            let mut deps = vec![];
            assert_eq!(resources.recursive_dependencies("permissioned.fn", &mut deps, PERM01), Ok(()));
            assert_eq!(deps.iter().map(|dep| dep.name.to_string()).collect::<Vec<_>>(), vec!["permissioned.fn", "a.fn", "common.fn"]);
        }

        {
            let mut deps = vec![];
            assert_eq!(resources.recursive_dependencies("test.js", &mut deps, Default::default()), Err(ScriptletResourceError::InsufficientPermissions));
        }
        {
            let mut deps = vec![];
            assert_eq!(resources.recursive_dependencies("test.js", &mut deps, PERM01), Ok(()));
            assert_eq!(deps.iter().map(|dep| dep.name.to_string()).collect::<Vec<_>>(), vec!["test.js", "permissioned.fn", "a.fn", "common.fn", "b.fn"]);
        }

        {
            let mut deps = vec![];
            assert_eq!(resources.recursive_dependencies("deploop1.fn", &mut deps, Default::default()), Ok(()));
            assert_eq!(deps.iter().map(|dep| dep.name.to_string()).collect::<Vec<_>>(), vec!["deploop1.fn"]);
        }

        {
            let mut deps = vec![];
            assert_eq!(resources.recursive_dependencies("deploop2a.fn", &mut deps, Default::default()), Ok(()));
            assert_eq!(deps.iter().map(|dep| dep.name.to_string()).collect::<Vec<_>>(), vec!["deploop2a.fn", "deploop2b.fn"]);
        }

        assert_eq!(resources.get_scriptlet_resources([]), "");

        assert_eq!(resources.get_scriptlet_resources([("test, arg1, arg2", Default::default())]), "");

        assert_eq!(resources.get_scriptlet_resources([("test, arg1, arg2", PERM01)]), "permissioned\na\ncommon\nb\nfunction test() {}\ntry {\ntest(\"arg1\", \"arg2\")\n} catch ( e ) { }\n");

        // Note: `test` still gets inserted as a dependency before it becomes apparent that
        // `permissioned` is not authorized. However, this shouldn't have much detrimental effect.
        assert_eq!(resources.get_scriptlet_resources([("test-wrapper", Default::default())]), "function test() {}\n");
        assert_eq!(resources.get_scriptlet_resources([("test-wrapper", PERM01)]), "function test() {}\npermissioned\na\ncommon\nb\nfunction testWrapper() { test(arguments) }\ntry {\ntestWrapper()\n} catch ( e ) { }\n");

        assert_eq!(resources.get_scriptlet_resources([("test", PERM01), ("test-wrapper", PERM01)]), "permissioned\na\ncommon\nb\nfunction test() {}\nfunction testWrapper() { test(arguments) }\ntry {\ntest()\n} catch ( e ) { }\ntry {\ntestWrapper()\n} catch ( e ) { }\n");

        assert_eq!(resources.get_scriptlet_resources([("shared, argument", Default::default())]), "a\ncommon\nb\nfunction shared() { }\ntry {\nshared(\"argument\")\n} catch ( e ) { }\n");
        assert_eq!(resources.get_scriptlet_resources([("test, 1", PERM01), ("test-wrapper, 2", PERM01), ("shared, 3", Default::default())]), "permissioned\na\ncommon\nb\nfunction test() {}\nfunction testWrapper() { test(arguments) }\nfunction shared() { }\ntry {\ntest(\"1\")\n} catch ( e ) { }\ntry {\ntestWrapper(\"2\")\n} catch ( e ) { }\ntry {\nshared(\"3\")\n} catch ( e ) { }\n");
    }
}
