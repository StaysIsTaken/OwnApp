# Stage 1: Flutter Web bauen
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY . .

# API_URL ist nur noch die VORGABE dieses Bildes, keine Festlegung mehr:
# in der App laesst sich die Adresse jederzeit umstellen (Login-Bildschirm
# und Einstellungen). Ein fremder Betreiber braucht also kein eigenes Bild.
ARG API_URL
RUN flutter pub get
RUN flutter build web --release --dart-define=API_URL=$API_URL

# Stage 2: nginx zum Serven
FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]