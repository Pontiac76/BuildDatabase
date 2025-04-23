# BuildDatabase

**BuildDatabase** is a Free Pascal (FPC) and Lazarus-based application designed to track and manage PC hardware components designed to run in the Windows environment. It dynamically constructs a SQLite3 database schema and user interface based on a declarative `structure.ini` file to assist in what hardware is present and can be used in certain builds.

The intent is to catalogue all the specific bits of hardware I have ownership of and be able to quickly determine if the part is assigned to a build and only provide parts that are compatible with the motherboard and OS, etc.

There is also ZERO attempt at hiding facts about what is being written to the platter.  Being that you have the source code, you see how the databases are constructed, and you can use tooling of your choice to read the database file and perform your own queries.

# AI Assisted Project
For some reason, people think its important to see this.

My code is built moreso with direct communications with OpenAIs ChatGPT system and sometimes Anthropics ClaudeAI systems.  The code generated in this project is a product of both the AI toolings and my intents of it writing code with straight up wording and instructions, and my own specific code and coding style.  What the AI has generated is based on training from 3rd party information, reading the Lazarus/Free Pascal, and whatever other sources it gathers to "understand" how Pascal works, but, no code here was a direct byte for byte copy of any other code found anywhere else on the internet.  I have zero control on what it reads or how.

I may not understand the byte-code involved in getting the LLMs trained, but I do understand that this tooling gathers its information from 3rd party sources sometimes ignoring copyright.  That is not the intention of the author to 'steal' or 'borrow' someones code, but there's only so many ways you can write an "if" statement before you end up getting into who wrote what first.

The logic the AI follows in its creation of source code is via my own logic process developed over 4 decades of programming experience in various DOS and PC based experience.  I vet every single line it provides and I do correct a lot of assumptions and code I'd never use for various reasons.

If there is a significant chunk of code that you feel is in violation to your own project, present facts to me in a ticket, and we'll discuss it.  I have no issues having a public chat regarding ownership of code.

## Features

- **Dynamic UI Generation**: Builds the user interface at runtime using Lazarus frames, guided by the `structure.ini` configuration.
- **SQLite3 Integration**: Utilizes SQLite3 for data storage, with the schema defined in `structure.ini`.
- **Component Management**: Tracks individual hardware components and their association with specific builds (computer cases).
- **Build Association Rules**:
  - Each component can be assigned to one build.
  - Components are not shared between builds.
  - Components can exist without being assigned to any build.

## Technical Overview

- **Language**: Free Pascal (FPC)
- **IDE**: Lazarus
- **Database**: SQLite3
- **Configuration**: `structure.ini` defines the database schema and UI layout.
- **UI Components**: Constructed dynamically using Lazarus frames with uniquely named components.
- **Metadata Management**: Employs a `LayoutMap` SQLite table to normalize field metadata.

## Usage

1. Define your hardware components and builds in the `structure.ini` file. (The included INI is what I run in "production" as this time)
2. Run the application; it will parse `structure.ini`, create the SQLite3 database, and generate the corresponding UI.
3. Use the UI to manage and track your hardware components and their associations with builds.

Once the SQLite3 database has been created, you can use either the SQLite3 application, or some other tooling that will read the file.  There is no encrpytion, there is no method of securing the files.

## Project Structure

- `structure.ini`: Defines the database schema and UI layout.  This is basically your `Infrastructure as Code` or IaC
- `LayoutMap` Table: Stores normalized metadata for UI rendering in the SQLite3 database.

## Contributing

Contributions are welcome. Please ensure that any code changes adhere to the project's coding standards and are thoroughly tested.
