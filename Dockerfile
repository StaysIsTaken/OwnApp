# Stage 1: Flutter Web bauen
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY . .

ARG API_URL
RUN flutter pub get
RUN flutter build web --release --dart-define=API_URL=$API_URL

# Stage 2: nginx zum Serven
FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]