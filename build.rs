use ethers_contract_abigen::Abigen;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Watch the ABI file so build.rs reruns when it changes
    println!("cargo:rerun-if-changed=src/contracts/EnergyDataBridge.json");

    // Generate Rust bindings from the ABI
    Abigen::new("EnergyDataBridge", "./src/contracts/EnergyDataBridge.json")?
        .generate()?
        .write_to_file("./src/contract_data.rs")?;

    Ok(())
}
