FROM golang:1.23-alpine

WORKDIR /app

COPY go.mod go.sum ./

RUN go mod download

COPY . ./

# Copy swagger docs from the parent context
COPY ./api/swagger ./api/swagger

RUN CGO_ENABLED=0 GOOS=linux go build -o /rhea

CMD ["/rhea"]
