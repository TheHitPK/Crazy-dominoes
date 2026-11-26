# Cuentas y ranked en Supabase

El ranked en línea guarda la ficha de cada jugador (liga, PR, temporada) en
una base de datos de Supabase. Solo el servidor de Render habla con ella; los
teléfonos hablan con el servidor, como siempre.

```
teléfono ──(wss)──> servidor de Render ──(HTTPS + clave de servicio)──> Supabase
```

Sin las claves, el servidor sigue funcionando y guarda las cuentas en un
archivo. En Render ese archivo se borra cada vez que el servidor se reinicia,
y el plan gratis se reinicia cada vez que se duerme.

## 1. Crear el proyecto (5 minutos)

1. Entra en https://supabase.com y crea una cuenta. Puedes entrar con GitHub.
2. **New project**:
   - Nombre: `crazy-dominoes`.
   - Contraseña de la base de datos: genera una y guárdala. El juego no la
     usa, pero Supabase la pide.
   - Región: la más cercana a Render. Si tu servicio de Render está en
     Oregón, elige **West US (Oregon)**.
   - Plan gratis.
3. Espera a que termine de crearse (1-2 minutos).

## 2. Crear la tabla

1. En el menú de la izquierda: **SQL Editor → New query**.
2. Pega todo el contenido de [supabase.sql](supabase.sql) y pulsa **Run**.
   Debe decir "Success. No rows returned".
3. En **Table Editor** aparece la tabla `players`, vacía.

## 3. Copiar las dos claves

En **Project Settings** (rueda dentada) → **API**:
- **Project URL**: algo como `https://abcdxyz.supabase.co`.
- **service_role** (en "Project API keys", pulsa *Reveal*): una clave larga
  que empieza por `eyJ…`, o `sb_secret_…` en los proyectos nuevos.

> ⚠️ La clave **service_role** da acceso total a la base de datos. No la
> pegues en el chat, en el código ni en GitHub. Solo va en Render (paso 4)
> y, si quieres probar en este PC, en `servidor/supabase.env` (paso 5), que
> Git ignora.

## 4. Ponerlas en Render

1. https://dashboard.render.com → servicio **crazy-dominoes** → **Environment**.
2. **Add Environment Variable** dos veces:
   - `SUPABASE_URL` = la Project URL.
   - `SUPABASE_SERVICE_KEY` = la clave service_role.
3. **Save Changes**. Render reinicia el servidor.
4. En **Logs** debe salir `[nube] Supabase: https://…supabase.co`. Si sale
   `[nube] sin SUPABASE_URL`, revisa los nombres de las variables.

`render.yaml` ya declara estas dos variables (`sync: false`): si algún día
recreas el servicio desde el Blueprint, Render te las pedirá.

## 5. Probar en este PC (opcional)

Crea `servidor/supabase.env` con estas dos líneas:

```
SUPABASE_URL=https://abcdxyz.supabase.co
SUPABASE_SERVICE_KEY=tu_clave_service_role
```

`servidor/iniciar_servidor.bat` lo lee si existe. Luego abre el juego con
`-- --ranked --server-addr=localhost:8910`.

## 6. Publicar

El ranked necesita las tres piezas a la vez, como cualquier cambio de red:
- **El servidor nuevo**: `git push` a la rama que despliega Render.
- **La web exportada de nuevo**.
- **Un APK nuevo.**

Las APK viejas siguen funcionando con el servidor nuevo, pero no tienen el
botón de ranked en línea.

## Más adelante: Google Play Juegos

Hoy la cuenta va unida a la instalación (el token privado del teléfono). Si
se borra la app, se pierde. Con Google Play Juegos:
1. El juego pide a Google un *server auth code* al iniciar sesión.
2. El servidor lo canjea con Google por el ID del jugador.
3. Ese ID se guarda en `players` (una columna `google_id`).

Desde entonces la cuenta se recupera en cualquier teléfono. Necesita la
cuenta de Google Play Console.
