//! meow-oraculo-tema — lê a RECEITA de um tema (a árvore `*.Builder/v<n>` no
//! formato do cosmic-config), chama o `ThemeBuilder::build()` do libcosmic da
//! revisão com que foi compilado e devolve o PRODUTO.
//!
//!   meow-oraculo-tema <dark|light> <dir-cosmic>
//!
//! `<dir-cosmic>` é um diretório no formato de `~/.config/cosmic` que contém a
//! árvore `com.system76.CosmicTheme.<Dark|Light>.Builder/v<n>`.
use cosmic_config::CosmicConfigEntry;
use cosmic_theme::ThemeBuilder;
use std::process::ExitCode;

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 3 || !matches!(args[1].as_str(), "dark" | "light") {
        eprintln!("uso: meow-oraculo-tema <dark|light> <dir-cosmic>");
        return ExitCode::from(2);
    }
    // O cosmic-config resolve `<XDG_CONFIG_HOME>/cosmic/<id>/v<n>`; o pai do
    // diretório dado faz esse papel.
    let dir = std::path::Path::new(&args[2]);
    let pai = match dir.parent() {
        Some(p) if dir.file_name().is_some_and(|n| n == "cosmic") => p,
        _ => {
            eprintln!("o diretório tem de se chamar `cosmic` (o formato de ~/.config/cosmic)");
            return ExitCode::from(2);
        }
    };
    // SAFETY: o programa tem uma thread só, e a variável é lida depois.
    unsafe { std::env::set_var("XDG_CONFIG_HOME", pai) };

    let config = if args[1] == "dark" { ThemeBuilder::dark_config() } else { ThemeBuilder::light_config() };
    let config = match config {
        Ok(c) => c,
        Err(e) => {
            eprintln!("não abri a receita: {e}");
            return ExitCode::from(2);
        }
    };
    // `get_entry` devolve o que conseguiu ler MESMO quando um campo falha (o
    // erro vem junto).
    let builder = match ThemeBuilder::get_entry(&config) {
        Ok(b) => b,
        Err((erros, b)) => {
            for e in erros {
                eprintln!("campo da receita ilegível, vale o padrão: {e}");
            }
            b
        }
    };
    let tema = builder.build();
    match serde_json::to_string(&tema) {
        Ok(s) => {
            println!("{s}");
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("não serializei o tema: {e}");
            ExitCode::from(2)
        }
    }
}
