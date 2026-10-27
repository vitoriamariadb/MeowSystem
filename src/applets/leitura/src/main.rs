use cosmic::app::Core;
use cosmic::applet::padded_control;
use cosmic::cosmic_config::cosmic_config_derive::CosmicConfigEntry;
use cosmic::cosmic_config::{self, Config, ConfigGet, ConfigSet, CosmicConfigEntry};
use cosmic::iced::{Alignment, Length, Limits, Subscription, window, window::Id};
use cosmic::surface::action::{app_popup, destroy_popup};
use cosmic::theme;
use cosmic::widget::{Column, Row, Slider, container, divider, icon, spin_button, text, toggler};
use cosmic::{Action, Element, Task};

const ID: &str = "com.meowsystem.AppletLeitura";

const NS_COMPOSITOR: &str = "com.system76.CosmicComp";
const NS_COMPOSITOR_V: u64 = 1;

const NS_ESTADO: &str = "com.meowsystem.AppletLeitura";
const NS_ESTADO_V: u64 = 1;

const ARTE_LUA: &[u8] = include_bytes!("../../../../packs/meowsystem/icones/sistema/leitura-r2.svg");
const ARTE_SOL: &[u8] = include_bytes!("../../../../packs/meowsystem/icones/sistema/leitura-s3.svg");
const ARTE_LIVRO: &[u8] = include_bytes!("../../../../packs/meowsystem/icones/sistema/leitura-r1.svg");
const ARTE_HALO: &[u8] = include_bytes!("../../../../packs/meowsystem/icones/sistema/leitura-r6.svg");

const ICONE_ROTULO: u16 = 16;

const NEUTRO: u32 = 6500;
const PISO: u32 = 1000;
const PASSO_K: u32 = 100;
const PASSO_TEXTURA: u32 = 5;
const PASSO_MINUTO: i32 = 15;

const FREIO_ARRASTO: std::time::Duration = std::time::Duration::from_secs(2);

const PADRAO_K: u32 = 3500;
const PADRAO_TEXTURA: f32 = 0.35;
const PADRAO_INICIO: &str = "18:00";
const PADRAO_FIM: &str = "07:00";

#[derive(Clone, Debug, PartialEq, CosmicConfigEntry)]
#[version = 1]
pub struct Chaves {
    pub leitura_temperatura: u32,
    pub leitura_textura: f32,
    pub leitura_agenda: bool,
    pub leitura_hora_inicio: String,
    pub leitura_hora_fim: String,
}

#[derive(Clone, Debug, Default, PartialEq, CosmicConfigEntry)]
#[version = 1]
pub struct Ponto {
    pub ultima_temperatura: u32,
    pub ultima_textura: f32,
}

impl Default for Chaves {
    fn default() -> Self {
        Self {
            leitura_temperatura: 0,
            leitura_textura: 0.0,
            leitura_agenda: true,
            leitura_hora_inicio: PADRAO_INICIO.to_string(),
            leitura_hora_fim: PADRAO_FIM.to_string(),
        }
    }
}

fn minutos_de_hhmm(v: &str) -> Option<i32> {
    if let Some((h, m)) = v.split_once(':') {
        if !(1..=2).contains(&h.len()) || m.len() != 2 {
            return None;
        }
        if !h.bytes().all(|b| b.is_ascii_digit()) || !m.bytes().all(|b| b.is_ascii_digit()) {
            return None;
        }
        let (h, m): (i32, i32) = (h.parse().ok()?, m.parse().ok()?);
        return (h <= 23 && m <= 59).then_some(h * 60 + m);
    }
    if v.is_empty() || !v.bytes().all(|b| b.is_ascii_digit()) {
        return None;
    }
    let m: i64 = v.parse().ok()?;
    (m <= 1439).then_some(m as i32)
}

fn ponta_do_horario(bruto: &str, padrao: &str) -> i32 {
    minutos_de_hhmm(bruto.trim())
        .or_else(|| minutos_de_hhmm(padrao))
        .unwrap_or(0)
}

fn agora_em_minutos() -> i32 {
    let agora = jiff::Zoned::now();
    i32::from(agora.hour()) * 60 + i32::from(agora.minute())
}

fn hhmm_de_minutos(v: i32) -> String {
    let v = v.rem_euclid(1440);
    format!("{:02}:{:02}", v / 60, v % 60)
}

struct AppletLeitura {
    core: Core,
    popup: Option<Id>,
    chaves: Chaves,
    conf: Option<Config>,
    estado: Option<Config>,
    ultima_temp: u32,
    ultima_textura: f32,
    arrastando: bool,
    ultimo_toque: std::time::Instant,
    estado_gravado: Option<(u32, f32)>,
    compositor_le: bool,
}

#[derive(Clone, Debug)]
enum Message {
    AbreFecha,
    PopupFechou(Id),
    Ligar(bool),
    Temperatura(u32),
    Textura(u32),
    Soltou,
    Agendar(bool),
    HoraInicio(i32),
    HoraFim(i32),
    DiscoMudou(Chaves),
    EstadoMudou(Ponto),
    Minuto,
}

impl AppletLeitura {
    fn ligado(&self) -> bool {
        self.chaves.leitura_temperatura != 0 || self.chaves.leitura_textura > 0.0
    }

    fn e_noite(&self) -> bool {
        let ini = ponta_do_horario(&self.chaves.leitura_hora_inicio, PADRAO_INICIO);
        let fim = ponta_do_horario(&self.chaves.leitura_hora_fim, PADRAO_FIM);
        let agora = agora_em_minutos();
        if ini == fim {
            true
        } else if ini > fim {
            agora >= ini || agora < fim
        } else {
            agora >= ini && agora < fim
        }
    }

    fn arte_da_barra(&self) -> &'static [u8] {
        if self.e_noite() { ARTE_LUA } else { ARTE_SOL }
    }

    fn selo(arte: &'static [u8]) -> Element<'static, Message> {
        icon::icon(icon::from_svg_bytes(arte).symbolic(true))
            .size(ICONE_ROTULO)
            .into()
    }

    fn grava_temperatura(&mut self, v: u32) {
        match self.conf.as_ref() {
            Some(c) => {
                if let Err(e) = self.chaves.set_leitura_temperatura(c, v) {
                    eprintln!("meow-applet-leitura: leitura_temperatura: {e}");
                }
            }
            None => self.chaves.leitura_temperatura = v,
        }
    }

    fn grava_textura(&mut self, v: f32) {
        match self.conf.as_ref() {
            Some(c) => {
                if let Err(e) = self.chaves.set_leitura_textura(c, v) {
                    eprintln!("meow-applet-leitura: leitura_textura: {e}");
                }
            }
            None => self.chaves.leitura_textura = v,
        }
    }

    fn lembra_ponto(&mut self) {
        if self.chaves.leitura_temperatura != 0 {
            self.ultima_temp = self.chaves.leitura_temperatura;
        }
        if self.chaves.leitura_textura > 0.0 {
            self.ultima_textura = self.chaves.leitura_textura;
        }
        let par = (self.ultima_temp, self.ultima_textura);
        if self.estado_gravado == Some(par) {
            return;
        }
        if let Some(e) = self.estado.as_ref() {
            let _ = e.set::<u32>("ultima_temperatura", par.0);
            let _ = e.set::<f32>("ultima_textura", par.1);
            self.estado_gravado = Some(par);
        }
    }
}

impl cosmic::Application for AppletLeitura {
    type Executor = cosmic::SingleThreadExecutor;
    type Flags = ();
    type Message = Message;
    const APP_ID: &'static str = ID;

    fn core(&self) -> &Core {
        &self.core
    }

    fn core_mut(&mut self) -> &mut Core {
        &mut self.core
    }

    fn init(core: Core, _flags: Self::Flags) -> (Self, Task<Action<Self::Message>>) {
        let conf = Config::new(NS_COMPOSITOR, NS_COMPOSITOR_V).ok();
        let estado = Config::new_state(NS_ESTADO, NS_ESTADO_V).ok();

        let chaves = conf
            .as_ref()
            .map(|c| match Chaves::get_entry(c) {
                Ok(v) => v,
                Err((_erros, v)) => v,
            })
            .unwrap_or_default();

        let ultima_temp = estado
            .as_ref()
            .and_then(|e| e.get::<u32>("ultima_temperatura").ok())
            .filter(|v| (PISO..NEUTRO).contains(v))
            .unwrap_or(PADRAO_K);
        let ultima_textura = estado
            .as_ref()
            .and_then(|e| e.get::<f32>("ultima_textura").ok())
            .filter(|v| *v > 0.0 && *v <= 1.0)
            .unwrap_or(PADRAO_TEXTURA);

        (
            Self {
                core,
                popup: None,
                chaves,
                conf,
                estado,
                ultima_temp,
                ultima_textura,
                arrastando: false,
                ultimo_toque: std::time::Instant::now(),
                estado_gravado: None,
                compositor_le: compositor_vivo_le_as_chaves(),
            },
            Task::none(),
        )
    }

    fn on_close_requested(&self, id: window::Id) -> Option<Message> {
        Some(Message::PopupFechou(id))
    }

    fn update(&mut self, message: Message) -> Task<Action<Self::Message>> {
        match message {
            Message::AbreFecha => return self.abre_fecha(),
            Message::PopupFechou(id) => {
                if self.popup == Some(id) {
                    self.popup = None;
                    self.arrastando = false;
                }
            }
            Message::Ligar(ligar) => {
                if ligar {
                    let (t, x) = (self.ultima_temp, self.ultima_textura);
                    self.grava_temperatura(t);
                    self.grava_textura(x);
                } else {
                    self.lembra_ponto();
                    self.grava_temperatura(0);
                    self.grava_textura(0.0);
                }
            }
            Message::Temperatura(v) => {
                self.arrastando = true;
                self.ultimo_toque = std::time::Instant::now();
                let v = if v >= NEUTRO { 0 } else { v.max(PISO) };
                self.grava_temperatura(v);
                if v != 0 {
                    self.ultima_temp = v;
                }
            }
            Message::Textura(p) => {
                self.arrastando = true;
                self.ultimo_toque = std::time::Instant::now();
                let x = (p.min(100) as f32) / 100.0;
                self.grava_textura(x);
                if x > 0.0 {
                    self.ultima_textura = x;
                }
            }
            Message::Soltou => {
                self.arrastando = false;
                self.lembra_ponto();
            }
            Message::Agendar(v) => {
                if let Some(c) = self.conf.as_ref() {
                    if let Err(e) = self.chaves.set_leitura_agenda(c, v) {
                        eprintln!("meow-applet-leitura: leitura_agenda: {e}");
                    }
                } else {
                    self.chaves.leitura_agenda = v;
                }
            }
            Message::HoraInicio(m) => {
                let hhmm = hhmm_de_minutos(m);
                if let Some(c) = self.conf.as_ref() {
                    if let Err(e) = self.chaves.set_leitura_hora_inicio(c, hhmm) {
                        eprintln!("meow-applet-leitura: leitura_hora_inicio: {e}");
                    }
                } else {
                    self.chaves.leitura_hora_inicio = hhmm;
                }
            }
            Message::HoraFim(m) => {
                let hhmm = hhmm_de_minutos(m);
                if let Some(c) = self.conf.as_ref() {
                    if let Err(e) = self.chaves.set_leitura_hora_fim(c, hhmm) {
                        eprintln!("meow-applet-leitura: leitura_hora_fim: {e}");
                    }
                } else {
                    self.chaves.leitura_hora_fim = hhmm;
                }
            }
            Message::DiscoMudou(chaves) => {
                if self.arrastando && self.ultimo_toque.elapsed() < FREIO_ARRASTO {
                    return Task::none();
                }
                self.arrastando = false;
                self.chaves = chaves;
            }
            Message::Minuto => {}
            Message::EstadoMudou(p) => {
                let temp_ok = (PISO..NEUTRO).contains(&p.ultima_temperatura);
                let textura_ok = p.ultima_textura > 0.0 && p.ultima_textura <= 1.0;
                if temp_ok {
                    self.ultima_temp = p.ultima_temperatura;
                }
                if textura_ok {
                    self.ultima_textura = p.ultima_textura;
                }
                if temp_ok && textura_ok {
                    self.estado_gravado = Some((self.ultima_temp, self.ultima_textura));
                }
            }
        }
        Task::none()
    }

    fn subscription(&self) -> Subscription<Self::Message> {
        Subscription::batch([
            self.core
                .watch_config::<Chaves>(NS_COMPOSITOR)
                .map(|atualizacao| {
                    for e in &atualizacao.errors {
                        if !chave_apenas_ausente(e) {
                            eprintln!("meow-applet-leitura: lendo o disco: {e}");
                        }
                    }
                    Message::DiscoMudou(atualizacao.config)
                }),
            cosmic::iced::time::every(std::time::Duration::from_secs(60)).map(|_| Message::Minuto),
            self.core
                .watch_state::<Ponto>(NS_ESTADO)
                .map(|atualizacao| Message::EstadoMudou(atualizacao.config)),
        ])
    }

    fn view(&self) -> Element<'_, Message> {
        self.core
            .applet
            .icon_button_from_handle(icon::from_svg_bytes(self.arte_da_barra()).symbolic(true))
            .on_press_down(Message::AbreFecha)
            .into()
    }

    fn view_window(&self, _id: Id) -> Element<'_, Message> {
        let ligado = self.ligado();

        let interruptor = padded_control(
            Row::new()
                .push(Self::selo(self.arte_da_barra()))
                .push(
                    toggler(ligado)
                        .on_toggle(Message::Ligar)
                        .label("Modo De Leitura".to_string())
                        .text_size(14)
                        .width(Length::Fill),
                )
                .spacing(8)
                .align_y(Alignment::Center),
        );

        let k = if self.chaves.leitura_temperatura == 0 {
            NEUTRO
        } else {
            self.chaves.leitura_temperatura.clamp(PISO, NEUTRO)
        };
        let rotulo_k = if self.chaves.leitura_temperatura == 0 {
            "Desligado".to_string()
        } else {
            format!("{k} K")
        };
        let temperatura = padded_control(
            Column::new()
                .push(
                    Row::new()
                        .push(Self::selo(ARTE_SOL))
                        .push(text::body("Temperatura").width(Length::Fill))
                        .push(text::body(rotulo_k))
                        .spacing(8)
                        .align_y(Alignment::Center),
                )
                .push(
                    Slider::new(PISO..=NEUTRO, k, Message::Temperatura)
                        .step(PASSO_K)
                        .name("Temperatura")
                        .on_release(Message::Soltou),
                )
                .spacing(4),
        );

        let pct = (self.chaves.leitura_textura.clamp(0.0, 1.0) * 100.0).round() as u32;
        let textura = padded_control(
            Column::new()
                .push(
                    Row::new()
                        .push(Self::selo(ARTE_LIVRO))
                        .push(text::body("Textura De Papel").width(Length::Fill))
                        .push(text::body(format!("{pct}%")))
                        .spacing(8)
                        .align_y(Alignment::Center),
                )
                .push(
                    Slider::new(0u32..=100u32, pct, Message::Textura)
                        .step(PASSO_TEXTURA)
                        .name("Textura De Papel")
                        .on_release(Message::Soltou),
                )
                .spacing(4),
        );

        let agendar = padded_control(
            Row::new()
                .push(Self::selo(ARTE_HALO))
                .push(
                    toggler(self.chaves.leitura_agenda)
                        .on_toggle(Message::Agendar)
                        .label("Agendar".to_string())
                        .text_size(14)
                        .width(Length::Fill),
                )
                .spacing(8)
                .align_y(Alignment::Center),
        );

        let ini = ponta_do_horario(&self.chaves.leitura_hora_inicio, PADRAO_INICIO);
        let fim = ponta_do_horario(&self.chaves.leitura_hora_fim, PADRAO_FIM);

        let bloco_horario: Option<Element<'_, Message>> = if self.chaves.leitura_agenda {
            let janela_cheia = (ini == fim).then(|| {
                padded_control(text::caption(
                    "Início e fim iguais: o modo de leitura vale o dia inteiro.",
                ))
            });

            Some(
                Column::new()
                    .push(padded_control(
                        Row::new()
                            .push(text::body("Das"))
                            .push(realce(spin_button(
                                hhmm_de_minutos(ini),
                                "hora de início",
                                ini,
                                PASSO_MINUTO,
                                0,
                                1440 - PASSO_MINUTO,
                                Message::HoraInicio,
                            )))
                            .push(text::body("Às"))
                            .push(realce(spin_button(
                                hhmm_de_minutos(fim),
                                "hora de fim",
                                fim,
                                PASSO_MINUTO,
                                0,
                                1440 - PASSO_MINUTO,
                                Message::HoraFim,
                            )))
                            .spacing(8)
                            .align_y(Alignment::Center),
                    ))
                    .push_maybe(janela_cheia)
                    .into(),
            )
        } else {
            None
        };

        let aviso: Option<Element<'_, Message>> = (!self.compositor_le).then(|| {
            Column::new()
                .push(padded_control(divider::horizontal::default()))
                .push(padded_control(text::caption(
                    "O compositor desta sessão ainda não lê estas chaves: \
                     o valor fica gravado e a tela obedece no próximo login.",
                )))
                .into()
        });

        let conteudo = Column::new()
            .push(interruptor)
            .push(padded_control(divider::horizontal::default()))
            .push(temperatura)
            .push(textura)
            .push(padded_control(divider::horizontal::default()))
            .push(agendar)
            .push_maybe(bloco_horario)
            .push_maybe(aviso)
            .padding([8, 0]);

        self.core.applet.popup_container(conteudo).into()
    }

    fn style(&self) -> Option<cosmic::iced::theme::Style> {
        Some(cosmic::applet::style())
    }
}

impl AppletLeitura {
    fn abre_fecha(&mut self) -> Task<Action<Message>> {
        if let Some(popup) = self.popup.take() {
            return tarefa_de_superficie(destroy_popup(popup));
        }
        let Some(pai) = self.core.main_window_id() else {
            eprintln!("meow-applet-leitura: sem janela principal — popup não abre");
            return Task::none();
        };

        tarefa_de_superficie(app_popup::<AppletLeitura>(
            |_| Default::default(),
            move |estado: &mut AppletLeitura| {
                let popup = Id::unique();
                let mut ajustes = estado
                    .core
                    .applet
                    .get_popup_settings(pai, popup, None, None, None);
                ajustes.positioner.size_limits = Limits::NONE
                    .max_width(400.0)
                    .min_width(320.0)
                    .min_height(200.0)
                    .max_height(1080.0);
                estado.popup = Some(popup);
                ajustes
            },
            None,
        ))
    }
}

fn chave_apenas_ausente(e: &cosmic_config::Error) -> bool {
    match e {
        cosmic_config::Error::NotFound => true,
        cosmic_config::Error::GetKey(_, io) => io.kind() == std::io::ErrorKind::NotFound,
        _ => false,
    }
}

fn realce<'a>(conteudo: impl Into<Element<'a, Message>>) -> Element<'a, Message> {
    container(conteudo).class(theme::Container::Dropdown).into()
}

fn tarefa_de_superficie(acao: cosmic::surface::Action) -> Task<Action<Message>> {
    cosmic::task::message(cosmic::Action::Cosmic(cosmic::app::Action::Surface(acao)))
}

fn compositor_vivo_le_as_chaves() -> bool {
    let Ok(dir) = std::fs::read_dir("/proc") else {
        return true;
    };
    for entrada in dir.flatten() {
        let nome = entrada.file_name();
        let Some(nome) = nome.to_str() else { continue };
        if !nome.bytes().all(|b| b.is_ascii_digit()) {
            continue;
        }
        let comm = std::fs::read_to_string(format!("/proc/{nome}/comm")).unwrap_or_default();
        if comm.trim() != "cosmic-comp" {
            continue;
        }
        let Ok(bytes) = std::fs::read(format!("/proc/{nome}/exe")) else {
            return true;
        };
        return bytes
            .windows(MARCADOR.len())
            .any(|janela| janela == MARCADOR);
    }
    true
}

const MARCADOR: &[u8] = b"AURORA-READING-MODE";

fn main() -> cosmic::iced::Result {
    cosmic::applet::run::<AppletLeitura>(())
}
