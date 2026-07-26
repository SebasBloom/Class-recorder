# Certificado de firma para desarrollo

## Para qué es esto

macOS ata los permisos de privacidad (grabación de pantalla, micrófono, cámara, accesibilidad) a la **identidad del binario**, no a su ubicación. Si la app se firma "ad-hoc", esa identidad cambia cada vez que se recompila y macOS vuelve a pedir los cuatro permisos desde cero.

En un proyecto donde casi cada prueba implica grabar pantalla, eso es insoportable. Con un certificado propio la identidad es estable y los permisos se dan una sola vez.

**No hace falta para la Fase 0.** Sí conviene tenerlo antes de arrancar la Fase 1, que es donde empiezan las pruebas de grabación.

## Por qué va por terminal

En macOS 26 Apple eliminó la app Acceso a Llaveros, que era donde estaba el asistente para crear certificados. Ahora el camino es la terminal.

## Los pasos

Pegá esto en la Terminal, bloque por bloque, parado en la carpeta del proyecto.

**1. Crear el certificado y la llave**

```bash
cd ~/grabador-bloomind
openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 3650 \
  -keyout /tmp/llave.pem -out /tmp/certificado.pem \
  -subj "/CN=Bloomind Desarrollo" \
  -addext "basicConstraints=critical,CA:true" \
  -addext "keyUsage=critical,digitalSignature,keyCertSign" \
  -addext "extendedKeyUsage=critical,codeSigning"

openssl pkcs12 -export -out /tmp/identidad.p12 \
  -inkey /tmp/llave.pem -in /tmp/certificado.pem \
  -name "Bloomind Desarrollo" -passout pass:
```

**2. Meterlo al llavero**

Te va a pedir la contraseña de tu Mac. El `-T /usr/bin/codesign` es para que `codesign` pueda usar la llave sin preguntarte cada vez.

```bash
security import /tmp/identidad.p12 \
  -k ~/Library/Keychains/login.keychain-db \
  -P "" -T /usr/bin/codesign
```

**3. Marcarlo como confiable para firmar código**

Acá macOS abre una ventana pidiendo tu contraseña de administrador.

```bash
sudo security add-trusted-cert -d -r trustRoot \
  -p codeSign -k /Library/Keychains/System.keychain \
  /tmp/certificado.pem
```

**4. Confirmar que quedó**

```bash
security find-identity -v -p codesigning
```

Tiene que aparecer una línea con `"Bloomind Desarrollo"`. Si dice `0 valid identities found`, algo falló en el paso 2 o 3.

**5. Decirle al script que lo use**

```bash
echo "Bloomind Desarrollo" > ~/grabador-bloomind/.firma-identidad
```

Ese archivo está fuera de git a propósito: es de tu máquina, no del proyecto.

**6. Borrar los archivos temporales**

Ya están dentro del llavero, no hacen falta sueltos y contienen la llave privada.

```bash
rm /tmp/llave.pem /tmp/certificado.pem /tmp/identidad.p12
```

**7. Probar**

```bash
cd ~/grabador-bloomind && ./construir.sh
```

Tiene que decir `==> Firmando con: Bloomind Desarrollo` en vez del aviso de ad-hoc, y terminar sin errores.

## Si algo falla

- **`security find-identity` no muestra nada:** la llave privada no quedó asociada al certificado. Repetí desde el paso 1 (los `openssl` no rompen nada, solo escriben en `/tmp`).
- **`codesign` dice "unable to build chain to self-signed root":** faltó el paso 3, el de confianza.
- **`codesign` pide la contraseña del llavero en cada compilación:** faltó el `-T /usr/bin/codesign` del paso 2. Se arregla en la app Contraseñas, o repitiendo el paso 2.
- **Después de todo esto macOS igual vuelve a pedir los permisos:** revisá que estés abriendo siempre la app desde `build/Grabador Bloomind.app` y no una copia vieja en otra carpeta.

## Nota sobre Iván

Esto es solo para la máquina donde se compila. La Mac de Iván recibe el `.app` ya firmado y sigue el flujo normal de Gatekeeper que está en el README de usuario: "Abrir de todos modos" en Configuración del Sistema, una sola vez.
