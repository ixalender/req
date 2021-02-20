# Req

A simple http client


## Dependencies

[Zig](https://ziglang.org/download/) 0.7.1



## Installation
After cloning the repository, run `zig build`. The req executable will be located in `zig-cache/bin/req`.


## Usage

```
req [METHOD] URL
  
  METHOD
        The HTTP method to be used for the request (GET, POST, PUT, DELETE, ...).
        By default req uses GET method.
  
  URL
        Default scheme is 'http://' if the URL does not include any.
  
  General Options:
  
    -h, --help      Usage information
  
```