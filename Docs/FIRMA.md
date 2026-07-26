# Certificado de firma para desarrollo

**Estado: hecho el 2026-07-26 en la Mac de Sebas.** Este documento queda como registro de cómo se hizo, por si hay que rehacerlo o replicarlo en otra máquina.

## Para qué es esto

macOS ata los permisos de privacidad (grabación de pantalla, micrófono, cámara, accesibilidad) a la **identidad del binario**, no a su ubicación. Si la app se firma "ad-hoc", esa identidad cambia en cada recompilación y macOS vuelve a pedir los cuatro permisos desde cero.

Con un certificado propio, el requisito designado del binario queda atado al certificado y no al contenido, así que sobrevive a las recompilaciones. Verificado: se compiló dos veces seguidas y el requisito quedó idéntico.

```
designated => identifier "com.bloomind.grabador" and certificate leaf = H"321c7ce…"
```

## Por qué va por terminal

En macOS 26 Apple eliminó la app Acceso a Llaveros, que era donde estaba el asistente para crear certificados. La terminal es el único camino.

## Los pasos, como funcionaron de verdad

**1. Crear el certificado y la llave**

```bash
cd /tmp
openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 \
  -keyout llave.pem -out certificado.pem \
  -subj "/CN=Bloomind Desarrollo" \
  -addext "basicConstraints=critical,CA:true" \
  -addext "keyUsage=critical,digitalSignature,keyCertSign" \
  -addext "extendedKeyUsage=critical,codeSigning"
```

**2. Empaquetarlo en formato que macOS acepte**

Acá está la trampa que costó dos intentos. OpenSSL 3 empaqueta los `.p12` con algoritmos modernos que el llavero de macOS rechaza con un `MAC verification failed` engañoso, que suena a contraseña equivocada y no lo es. Hay que pedirle explícitamente los algoritmos viejos. Y la contraseña no puede ir vacía.

```bash
openssl pkcs12 -export -out identidad.p12 \
  -inkey llave.pem -in certificado.pem \
  -name "Bloomind Desarrollo" \
  -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
  -passout pass:bloomind
```

**3. Meterlo al llavero**

El `-T /usr/bin/codesign` autoriza a la herramienta de firma a usar la llave.

```bash
security import identidad.p12 \
  -k ~/Library/Keychains/login.keychain-db \
  -P "bloomind" -T /usr/bin/codesign
```

Tiene que responder `1 identity imported.`

**4. Autorizar a codesign a usar la llave sin preguntar**

Sin este paso, el `-T` del paso anterior no alcanza: la primera firma abre una ventana pidiendo permiso y el proceso se queda colgado esperando. Se resuelve de cualquiera de las dos formas:

- Cuando salga la ventana, darle a **"Permitir siempre"**, no a "Permitir" a secas.
- O por adelantado, con este comando, que pide la contraseña de desbloqueo del Mac (se teclea a ciegas, la terminal no muestra nada mientras se escribe):

```bash
security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
  -k "" ~/Library/Keychains/login.keychain-db
```

**5. Decirle al script que lo use**

```bash
echo "Bloomind Desarrollo" > ~/grabador-bloomind/.firma-identidad
```

Ese archivo está fuera de git a propósito: es de la máquina que compila, no del proyecto.

**6. Borrar los temporales**

Ya están dentro del llavero, y los archivos sueltos contienen la llave privada.

```bash
rm /tmp/llave.pem /tmp/certificado.pem /tmp/identidad.p12
```

**7. Probar**

```bash
cd ~/grabador-bloomind && ./construir.sh
```

Tiene que decir `==> Firmando con: Bloomind Desarrollo` y terminar sin errores.

## Lo que NO hace falta

**No hace falta marcar el certificado como confiable con `sudo security add-trusted-cert`.** Se probó y `codesign` firma perfecto con un certificado autofirmado sin confianza en el sistema. El paso de sudo sobra.

Efecto secundario: `security find-identity -v -p codesigning` va a seguir diciendo `0 valid identities found`, porque el `-v` filtra por confianza en el sistema. **No es un error.** Para ver las identidades reales hay que correrlo sin el `-v`:

```bash
security find-identity -p codesigning
```

Ahí aparece `"Bloomind Desarrollo" (CSSMERR_TP_NOT_TRUSTED)`, que es lo esperado y firma sin problema.

## Si algo falla

- **`MAC verification failed during PKCS12 import`:** faltaron los algoritmos viejos del paso 2. No es la contraseña.
- **La firma se queda colgada sin terminar:** es el paso 4, hay una ventana esperando respuesta o falta la autorización.
- **`unable to build chain to self-signed root`:** si llegara a aparecer (no pasó acá), ahí sí haría falta el paso de confianza con sudo.
- **macOS igual vuelve a pedir los permisos:** revisá que estés abriendo siempre la app desde `build/Grabador Bloomind.app` y no una copia vieja.

## Nota sobre el llavero de Sebas

En su llavero ya existía otro certificado de firma, `"Bloomind Lab Local Signer"`, de un proyecto anterior. No se tocó. Este proyecto usa `"Bloomind Desarrollo"`, que es el que quedó configurado en `.firma-identidad`.

## Nota sobre Iván

Esto es solo para la máquina donde se compila. La Mac de Iván recibe el `.app` ya firmado y sigue el flujo normal de Gatekeeper del README de usuario: "Abrir de todos modos", una sola vez.
