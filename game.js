let Prolog;
let socket;

//carga el prolog del wasm

async function cargarProlog() {
    const swipl = await SWIPL({
        arguments: ["-q"],
        locateFile: (path) => `node_modules/swipl-wasm/dist/swipl/${path}`
    });
    Prolog = swipl.prolog;
    const resp = await fetch('main.pl');
    const codigo = await resp.text();
    Prolog.load_string(codigo);
    console.log("Prolog WASM listo");

    document.getElementById('btn-conectar').disabled = false;
    document.getElementById('btn-conectar').innerText = 'CONECTAR';
}

//conexion con websocket

function conectar() {
    const url = document.getElementById('input-servidor').value.trim();
    const nombre = document.getElementById('input-nombre').value.trim();

    if (!nombre) {
        document.getElementById('estado-conexion').innerText = 'Ingresá tu nombre';
        return;
    }

    // inicializamos el estado en Prolog
    const nombreEscapado = nombre.replace(/'/g, "\\'");
    Prolog.query(`iniciar_cliente('${nombreEscapado}')`).once();
    window.nombreJugador = nombre;

    document.getElementById('btn-conectar').disabled = true;
    document.getElementById('estado-conexion').innerText = 'Conectando...';

    socket = new WebSocket(url);

    socket.onopen = () => {
        document.getElementById('estado-conexion').innerText = 'Conectado, esperando al servidor...';
    };

    socket.onmessage = (event) => {
        procesarMensajeViaProlog(event.data);
    };

    socket.onerror = () => {
        document.getElementById('estado-conexion').innerText = 'Error de conexión al servidor';
        document.getElementById('btn-conectar').disabled = false;
    };

    socket.onclose = () => {
        document.getElementById('estado-conexion').innerText = 'Conexión cerrada';
    };
}

function enviar(texto) {
    socket.send(texto);
    log('→ ' + texto);
}

function log(texto) {
    const divLog = document.getElementById('log');
    if (!divLog) { console.log(texto); return; }
    const linea = document.createElement('div');
    linea.innerText = texto;
    divLog.appendChild(linea);
    divLog.scrollTop = divLog.scrollHeight;
}


//conexion con prolog

function escaparParaProlog(texto) {
    // escapamos backslashes y comillas dobles para meterlo en un string Prolog
    return texto.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
}

function procesarMensajeViaProlog(textoOriginal) {
    log('← ' + textoOriginal);
    const textoEscapado = escaparParaProlog(textoOriginal);

    const sol = Prolog.query(`recibir_linea("${textoEscapado}", Accion)`).once();

    if (!sol || !sol.success) {
        console.warn("Prolog no pudo interpretar:", textoOriginal);
        return;
    }

    const accion = sol.Accion;
    aplicarAccion(accion, textoOriginal);
}


// aplicar la accion que indica prolog 


function aplicarAccion(accion, textoOriginal) {
    // accion puede venir como string simple ('pedir_nombre')
    // o como compound (objeto con functor, ej: info/1)
    const tag = typeof accion === 'string' ? accion : nombreFunctor(accion);

    switch (tag) {
        case 'pedir_nombre':
            enviar(window.nombreJugador);
            break;

        case 'esperando_rival':
            document.getElementById('estado-conexion').innerText = 'Esperando al rival...';
            break;

        case 'inicio_juego':
            document.getElementById('inicio').style.display = 'none';
            document.getElementById('juego').classList.add('activo');
            document.getElementById('mensaje').innerText = textoOriginal;
            break;

        case 'actualizar_mesa':
            refrescarMesa();
            break;

        case 'inicio_turno':
            document.getElementById('turno').innerText = `Tu turno, ${window.nombreJugador}`;
            document.getElementById('mensaje').innerText = '';
            document.getElementById('opciones-lista').innerHTML = '';
            break;

        case 'mostrar_mano':
            // esperamos a que terminen de llegar las líneas numeradas
            break;

        case 'opcion_captura':
            // se va acumulando, refrescamos al final con pedir_jugada
            break;

        case 'linea_numerada':
            refrescarMano();
            break;

        case 'sin_capturas':
            document.getElementById('opciones-titulo').innerText = 'ELEGÍ UNA CARTA PARA DESCARTAR';
            break;

        case 'pedir_jugada':
            document.getElementById('opciones-titulo').innerText = 'JUGADAS DISPONIBLES';
            mostrarOpcionesCaptura();
            break;

        case 'pedir_descarte':
            mostrarOpcionesDescarte();
            break;

        case 'escoba':
            document.getElementById('mensaje').innerText = '¡¡¡ ESCOBA !!!';
            break;

        case 'jugada_realizada':
            document.getElementById('mensaje').innerText = textoOriginal;
            document.getElementById('opciones-lista').innerHTML = '';
            document.getElementById('turno').innerText = 'Esperando al rival...';
            break;

        case 'fin_partida':
            mostrarResultadoInicio();
            break;

        case 'linea_resultado':
            agregarLineaResultado(textoOriginal);
            break;

        case 'puntaje_parcial':
            actualizarPuntajeParcial(textoOriginal);
            break;

        case 'info':
            document.getElementById('mensaje').innerText = textoOriginal;
            break;

        case 'ignorar':
        default:
            break;
    }
}

function nombreFunctor(obj) {
    // los compounds que devuelve swipl-wasm exponen el nombre del functor
    // como una de las claves del objeto (junto con '$t' y 'functor')
    if (obj && obj.functor) return obj.functor;
    return 'desconocido';
}

//renderizar cartas

const NUMERO_A_ARCHIVO = {
    ancho: 1, sota: 10, caballo: 11, rey: 12,
    1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6, 7: 7
};

function cartaCompoundAString(compound) {
    // las cartas vuelven de Prolog como compound '-'(Numero, Palo)
    if (compound && compound['-']) {
        const partes = compound['-'][0];
        return `${partes[0]}-${partes[1]}`;
    }
    return String(compound);
}

function rutaImagenCarta(cartaStr) {
    const [num, palo] = cartaStr.split('-');
    const numArchivo = NUMERO_A_ARCHIVO[num] ?? num;
    return `cartas/${palo}-${numArchivo}.png`;
}

function crearElementoCarta(cartaStr, jugable, onClick) {
    const ruta = rutaImagenCarta(cartaStr);

    const carta = document.createElement('div');
    carta.classList.add('carta');
    if (jugable) carta.classList.add('jugable');

    carta.innerHTML = `<img class="carta-img" src="${ruta}" alt="${cartaStr}">`;

    if (jugable && onClick) carta.addEventListener('click', onClick);
    return carta;
}

function renderizarCartas(containerId, cartas, jugable, onClickFn) {
    const container = document.getElementById(containerId);
    container.innerHTML = '';
    cartas.forEach((carta, i) => {
        const el = crearElementoCarta(carta, jugable, jugable ? () => onClickFn(i) : null);
        container.appendChild(el);
    });
}

//refrescar la mesa

function refrescarMesa() {
    const sol = Prolog.query("obtener_mesa(Mesa)").once();
    const mesa = sol.Mesa.map(cartaCompoundAString);
    renderizarCartas('mesa-cartas', mesa, false, null);
}

function refrescarMano() {
    const sol = Prolog.query("obtener_mano(Mano)").once();
    const mano = sol.Mano.map(cartaCompoundAString);
    renderizarCartas('mano-cartas', mano, false, null);
}

//mostrar opciones

function mostrarOpcionesCaptura() {
    document.getElementById('mano-titulo').innerText = 'TU MANO';
    refrescarMano();

    const sol = Prolog.query("obtener_opciones(Opciones)").once();
    const opciones = sol.Opciones; // lista de strings Prolog

    const divOpciones = document.getElementById('opciones-lista');
    divOpciones.innerHTML = '';

    opciones.forEach((textoOpcion, i) => {
        const btn = document.createElement('button');
        btn.classList.add('btn-jugada');
        btn.innerText = String(textoOpcion).replace(/^\d+:\s*/, '');
        btn.onclick = () => enviarRespuesta(i + 1);
        divOpciones.appendChild(btn);
    });
}

function mostrarOpcionesDescarte() {
    document.getElementById('mano-titulo').innerText = 'ELEGÍ UNA CARTA PARA DESCARTAR';
    document.getElementById('opciones-lista').innerHTML = '';

    const sol = Prolog.query("obtener_mano(Mano)").once();
    const mano = sol.Mano.map(cartaCompoundAString);

    renderizarCartas('mano-cartas', mano, true, (i) => enviarRespuesta(i + 1));
}

function enviarRespuesta(indice) {
    const sol = Prolog.query(`responder_indice(${indice}, Texto)`).once();
    enviar(sol.Texto);
    document.getElementById('opciones-lista').innerHTML = '';
}

//resultado final

function mostrarResultadoInicio() {
    const juego = document.getElementById('juego');
    juego.innerHTML = `
        <div class="resultado">
            <h2>PARTIDA TERMINADA</h2>
            <div id="resultado-lineas"></div>
            <br>
            <button class="btn-principal" onclick="location.reload()">VOLVER A JUGAR</button>
        </div>
    `;
}

function agregarLineaResultado(texto) {
    const cont = document.getElementById('resultado-lineas');
    if (!cont) return;
    const p = document.createElement('p');
    if (texto.includes('RESULTADO FINAL')) {
        p.classList.add('ganador');
        p.innerText = '🏆 ' + texto.replace('EL RESULTADO FINAL ES:', '').trim();
    } else {
        p.classList.add('puntaje');
        p.innerText = texto;
    }
    cont.appendChild(p);
}

//puntaje parcial

function actualizarPuntajeParcial(texto) {
    const contenido = texto.replace('PUNTAJE: ', '');
    const partes = contenido.split(' | ');

    const cont = document.getElementById('puntaje');
    if (!cont) return;
    cont.innerHTML = '';

    partes.forEach(parte => {
        const [nombre, resto] = parte.split(': ');
        const cantidad = resto.replace(' cartas', '');
        const span = document.createElement('span');
        span.classList.add('jugador-puntaje');
        span.innerHTML = `${nombre}: <strong>${cantidad}</strong> cartas`;
        cont.appendChild(span);
    });
}


cargarProlog();