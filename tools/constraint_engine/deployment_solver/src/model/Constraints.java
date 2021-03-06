package model;

import java.util.ArrayList;
import java.util.List;

/**
 * POJO representing a set of constraints (user side) on a physical
 * infrastructure.
 * @author Dimitri Justeau
 */
public class Constraints {

    /**
     * Constraints on the cpu.
     */
    private CPU m_cpu;

    /**
     * Constraints on the ram.
     */
    private RAM m_ram;

    /**
     * Constraints on the network.
     */
    private Network m_network;

    /**
     * Constraints on the storage.
     */
    private Storage m_storage;

    /**
     * The min set of tags constraint.
     */
    private Integer[] m_tags_min;

    /**
     * The min set of tags constraint.
     */
    private Integer[] m_noTags;


    public Constraints() {
        this.m_cpu      = new CPU();
        this.m_ram      = new RAM();
        this.m_network  = new Network();
        this.m_storage  = new Storage();
        this.m_tags_min = new Integer[0];
        this.m_noTags  = new Integer[0];
    }

    public Constraints(CPU cpu, RAM ram, Network network, Storage storage, Integer[] tags_min, Integer[] noTags) {
        super();
        this.m_cpu      = cpu;
        this.m_ram      = ram;
        this.m_network  = network;
        this.m_storage  = storage;
        this.m_tags_min = tags_min;
        this.m_noTags   = noTags;
    }

    // GETTERS

    public CPU getCpu() {
        return m_cpu;
    }

    public RAM getRam() {
        return m_ram;
    }

    public Network getNetwork() {
        return m_network;
    }

    public Storage getStorage() {
        return m_storage;
    }

    public Integer[] getTagsMin() {
        return m_tags_min;
    }

    public Integer[] getNoTags() {
        return m_noTags;
    }

    // SETTERS

    public void setCpu(CPU cpu) {
        this.m_cpu = cpu;
    }

    public void setRam(RAM ram) {
        this.m_ram = ram;
    }

    public void setNetwork(Network network) {
        this.m_network = network;
    }

    public void setStorage(Storage storage) {
        this.m_storage = storage;
    }

    public void setTagsMin(Integer[] tags_min) {
        this.m_tags_min = tags_min;
    }

    public void setNoTags(Integer[] noTags) {
        this.m_noTags = noTags;
    }

    public String toString() {
        String constraints = "Constraints :";
        constraints += "\n" + "\t" + this.getCpu();
        constraints += "\n" + "\t" + this.getRam();
        constraints += "\n" + "\t" + this.getNetwork();
        constraints += "\n" + "\t" + this.getStorage();
        constraints += "\n" + "\t" + "Tags min :";
        for (Integer tag : this.getTagsMin()) {
            constraints += "\n" + "\t\t" + tag;
        }
        constraints += "\n" + "\t" + "No tags :";
        for (Integer tag : this.getNoTags()) {
            constraints += "\n" + "\t\t" + tag;
        }
        return constraints;
    }

    /**
     * POJO representing user constraints on the CPU of a host.
     * @author Dimitri Justeau
     */
    public static class CPU {

        /**
         * The minimum number of cores.
         */
        private int m_nb_cores_min;

        public CPU() {
            this.m_nb_cores_min = -1;
        }

        public CPU(int nb_cores_min) {
            super();
            this.m_nb_cores_min = nb_cores_min;
        }

        // GETTERS

        public int getNbCoresMin() {
            return m_nb_cores_min;
        }

        // SETTERS

        public void setNbCoresMin(int nb_cores_min) {
            this.m_nb_cores_min = nb_cores_min;
        }

        public String toString() {
            String cpu = "CPU :";
            cpu += "\n" + "\t\t" + "Nb of cores min : " + this.getNbCoresMin();
            return cpu;
        }
    }

    /**
     * POJO representing user constraints on the RAM of a host.
     * @author Dimitri Justeau
     */
    public static class RAM {

        /**
         * The minimum quantity of RAM.
         */
        private int m_qty_min;

        public RAM() {
            this.m_qty_min = -1;
        }

        public RAM(int qty_min) {
            super();
            this.m_qty_min = qty_min;
        }

        // GETTERS

        public int getQtyMin() {
            return m_qty_min;
        }

        // SETTERS

        public void setQtyMin(int qty_min) {
            this.m_qty_min = qty_min;
        }

        public String toString() {
            String ram = "RAM :";
            ram += "\n" + "\t\t" + "Qty min : " + this.getQtyMin();
            return ram;
        }
    }

    /**
     * POJO representing user constraints on the network features of a host.
     * @author Dimitri Justeau
     */
    public static class Network {

        /**
         * The ifaces of the network.
         */
        private List<Interface> m_interfaces;

        public Network() {
            this.m_interfaces = new ArrayList();
        }

        public Network(List<Interface> interfaces) {
            super();
            this.m_interfaces = interfaces;
        }

        // GETTERS AND SETTERS

        public List<Interface> getInterfaces() {
            return m_interfaces;
        }

        public void setInterfaces(List<Interface> interfaces) {
            this.m_interfaces = interfaces;
        }

        public String toString() {
            String net = "Network :";
            net += "\n" + "\t\t" + "Interfaces : ";
            for (Interface interf : this.getInterfaces()) {
                net += "\n" + "\t\t\t" + interf;
            }
            return net;
        }

        /**
         * POJO representing a interface constraint.
         * @author Dimitri Justeau
         */
        public static class Interface {

            /**
             * The min number of bonds (0 means that we want no bonding
             * configuration, -1 means wathever).
             */
            private int m_bonds_number_min;

            /**
             * The min set of NetIPs desired for the interface.
             */
            private List<Integer> m_netips_min;

            public Interface() {
                m_bonds_number_min = -1;
                m_netips_min = new ArrayList<Integer>();
            }

            // GETTERS AND SETTERS

            public int getBondsNumberMin() {
                return m_bonds_number_min;
            }

            public List<Integer> getNetIPsMin() {
                return m_netips_min;
            }

            public void setBondsNumberMin(int bonds_number_min) {
                this.m_bonds_number_min = bonds_number_min;
            }

            public void setNetIPsMin(List<Integer> netips_min) {
                this.m_netips_min = netips_min;
            }

            public String toString() {
                String net = "Interface :";
                net += "\n" + "\t\t\t\t" + "Nb of bonds min : "
                        + this.getBondsNumberMin();
                String netips = "[ ";
                for (int netip : this.getNetIPsMin()) {
                    netips += netip + " ";
                }
                net += "\n" + "\t\t\t\t" + "NetIPs min : " + netips + "]";
                return net;
            }
        }
    }

    /**
     * POJO representing user constraints on storage.
     * @author Dimitri Justeau
     */
    public static class Storage {

        /**
         * The minimum total storage size.
         */
        private int m_harddisks_nb_min;

        public Storage(int size_min) {
            this.m_harddisks_nb_min = size_min;
        }

        public Storage() {
            this(-1);
        }

        // GETTERS AND SETTERS

        public int getHardDisksNumberMin() {
            return this.m_harddisks_nb_min;
        }

        public void setHardDisksNumberMin(int total_size_min) {
            this.m_harddisks_nb_min = total_size_min;
        }

        public String toString() {
            String storage = "Storage :";
            storage += "\n" + "\t\t" + "Hard Disks number min : " + this.getHardDisksNumberMin();
            return storage;
        }
    }
}